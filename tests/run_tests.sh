#!/usr/bin/env bash

# ==============================================================================
#  gdiff Automated Testing Suite
#  Tests both bash/gdiff and fish/gdiff in isolated sandbox environments.
# ==============================================================================

set -uo pipefail

# Capture the original PATH immediately at startup
export ORIG_PATH="$PATH"

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(realpath "$TESTS_DIR/..")"
BASH_GDIFF="$REPO_ROOT/bash/gdiff"
FISH_GDIFF="$REPO_ROOT/fish/gdiff"
ORIG_RULE_FILE="$REPO_ROOT/share/rule.txt"

SANDBOX_DIR="/tmp/gdiff_sandbox_$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Stats
PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_TESTS=0

# Clean up sandbox on exit
cleanup() {
    export PATH="$ORIG_PATH"
    rm -rf "$SANDBOX_DIR"
}
trap cleanup EXIT

print_group_header() {
    local shell_name="$1"
    echo -e "\n${BOLD}${BLUE}======================================================================${RESET}"
    echo -e "${BOLD}${BLUE} Running tests for: $shell_name/gdiff${RESET}"
    echo -e "${BOLD}${BLUE}======================================================================${RESET}"
}

# Strip ANSI escape sequences from a stream/string
strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# Assert helper functions
assert_equals() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" != "$actual" ]; then
        echo -e "  ${RED}FAIL: $label mismatch${RESET}"
        echo -e "    Expected: '$expected'"
        echo -e "    Actual:   '$actual'"
        return 1
    fi
    return 0
}

assert_contains() {
    local label="$1"
    local substring="$2"
    local text="$3"
    if [[ "$text" != *"$substring"* ]]; then
        echo -e "  ${RED}FAIL: $label did not contain expected substring${RESET}"
        echo -e "    Expected substring: '$substring'"
        echo -e "    Actual text:        '$text'"
        return 1
    fi
    return 0
}

# Setup the sandbox environment with clean PATH (no host clipboard commands)
setup_sandbox() {
    # Restore original path so we can run commands to setup the sandbox
    export PATH="$ORIG_PATH"

    rm -rf "$SANDBOX_DIR"
    mkdir -p "$SANDBOX_DIR/bin"
    mkdir -p "$SANDBOX_DIR/home"
    mkdir -p "$SANDBOX_DIR/config"
    mkdir -p "$SANDBOX_DIR/repo"
    mkdir -p "$SANDBOX_DIR/share"

    export HOME="$SANDBOX_DIR/home"
    export XDG_CONFIG_HOME="$SANDBOX_DIR/config"
    export GDIFF_DEFAULT_RULE="$SANDBOX_DIR/share/rule.txt"
    
    # Configure mock clipboard
    export WAYLAND_DISPLAY="wayland-mock"
    export DISPLAY=":mock"
    export CLIPBOARD_FILE="$SANDBOX_DIR/clipboard.txt"

    # Symlink only essential system commands to sandbox bin, excluding clipboard tools.
    # This prevents host clipboard tools (e.g. wl-copy, xclip) from leaking into tests.
    for cmd in git bash fish sed cat mkdir cp rm basename dirname realpath printf expr tput uname id grep ls sh env which chmod touch; do
        local cmd_path
        cmd_path=$(command -v "$cmd" 2>/dev/null)
        if [ -n "$cmd_path" ]; then
            ln -sf "$cmd_path" "$SANDBOX_DIR/bin/$cmd"
        fi
    done

    # Create mock clipboard command binaries
    for cmd in wl-copy xclip xsel pbcopy clip.exe; do
        cat <<EOF > "$SANDBOX_DIR/bin/$cmd"
#!/usr/bin/env bash
cat - > "$CLIPBOARD_FILE"
EOF
        chmod +x "$SANDBOX_DIR/bin/$cmd"
    done

    export PATH="$SANDBOX_DIR/bin"
}

setup_git_repo() {
    local repo_dir="$SANDBOX_DIR/repo"
    cd "$repo_dir" || exit 1
    git init -q
    git config user.name "Tester"
    git config user.email "test@example.com"
}

# Helper to run a script and capture everything
run_gdiff() {
    local script_to_run="$1"
    shift
    
    if [[ "$SHELL_UNDER_TEST" == "bash" ]]; then
        bash "$script_to_run" "$@" 2> stderr.log > stdout.log
    elif [[ "$SHELL_UNDER_TEST" == "fish" ]]; then
        fish "$script_to_run" "$@" 2> stderr.log > stdout.log
    fi
    return $?
}

# Run a test case
run_test_case() {
    local test_num="$1"
    local name="$2"
    local setup_command="$3"
    local script_target="$4"
    local script_args="${5:-}"
    local input_pipe="${6:-}"
    
    local expected_exit_code="$7"
    local expected_stdout_sub="${8:-}"
    local expected_stderr_sub="${9:-}"
    local expected_clipboard_sub="${10:-}"

    ((TOTAL_TESTS++))
    echo -n "Test #$test_num: $name... "

  
    setup_sandbox
    
    $setup_command

    local target
    if [ "$script_target" = "original" ]; then
        if [ "$SHELL_UNDER_TEST" = "bash" ]; then
            target="$BASH_GDIFF"
        else
            target="$FISH_GDIFF"
        fi
    else
        # Copied version inside the sandbox to avoid git dev repo detection
        target="$SANDBOX_DIR/bin/gdiff"
        if [ "$SHELL_UNDER_TEST" = "bash" ]; then
            cp "$BASH_GDIFF" "$target"
        else
            cp "$FISH_GDIFF" "$target"
        fi
        chmod +x "$target"
    fi

    local exit_code=0
    cd "$SANDBOX_DIR/repo" || exit 1
    
    if [ -n "$input_pipe" ]; then
        echo "$input_pipe" | run_gdiff "$target" $script_args
        exit_code=$?
    else
        run_gdiff "$target" $script_args
        exit_code=$?
    fi

    local stdout_content
    stdout_content=$(cat stdout.log | strip_ansi)
    local stderr_content
    stderr_content=$(cat stderr.log | strip_ansi)

    local failed=0

    # Assert Exit Code
    if ! assert_equals "Exit code" "$expected_exit_code" "$exit_code"; then
        failed=1
    fi

    # Assert Stdout
    if [ -n "$expected_stdout_sub" ]; then
        if ! assert_contains "Stdout" "$expected_stdout_sub" "$stdout_content"; then
            failed=1
        fi
    fi

    # Assert Stderr
    if [ -n "$expected_stderr_sub" ]; then
        if ! assert_contains "Stderr" "$expected_stderr_sub" "$stderr_content"; then
            failed=1
        fi
    fi

    # Assert Clipboard
    if [ -n "$expected_clipboard_sub" ]; then
        if [ ! -f "$CLIPBOARD_FILE" ]; then
            echo -e "  ${RED}FAIL: Clipboard content expected but no clipboard file created${RESET}"
            failed=1
        else
            local clip_content
            clip_content=$(cat "$CLIPBOARD_FILE" | strip_ansi)
            if ! assert_contains "Clipboard" "$expected_clipboard_sub" "$clip_content"; then
                failed=1
            fi
        fi
    elif [ "$expected_exit_code" -eq 0 ] && \
         [[ "$script_args" != *"-p"* ]] && \
         [[ "$script_args" != *"--print"* ]] && \
         [[ "$script_args" != *"--rule-path"* ]] && \
         [[ "$script_args" != *"--restore-rule"* ]] && \
         [[ "$script_args" != *"--help"* ]] && \
         [[ "$script_args" != *"-h"* ]] && \
         [[ "$script_args" != *"--version"* ]] && \
         [[ "$script_args" != *"-v"* ]]; then
        # Default behavior should use clipboard
        if [ ! -f "$CLIPBOARD_FILE" ] && [[ "$expected_stderr_sub" != *"No clipboard tool found"* ]] && [[ "$expected_stderr_sub" != *"Failed to copy"* ]]; then
            echo -e "  ${RED}FAIL: Expected clipboard interaction but clipboard file does not exist${RESET}"
            failed=1
        fi
    fi

    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}PASS${RESET}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}FAIL${RESET}"
        echo -e "    --- DEBUG INFO ---"
        echo -e "    Arguments:  $script_args"
        echo -e "    Exit Code:  $exit_code (Expected $expected_exit_code)"
        echo -e "    Stdout:     \n$stdout_content"
        echo -e "    Stderr:     \n$stderr_content"
        if [ -f "$CLIPBOARD_FILE" ]; then
            echo -e "    Clipboard:  \n$(cat "$CLIPBOARD_FILE" | strip_ansi)"
        fi
        echo -e "    ------------------"
        ((FAILED_TESTS++))
    fi
}

# Test cases definitions

# Empty setup
setup_none() {
    true
}

setup_staged_changes() {
    setup_git_repo
    echo "original content" > myfile.txt
    git add myfile.txt
    git commit -m "initial commit" -q
    echo "modified content" > myfile.txt
    git add myfile.txt
    
    # Restores a rule to XDG config so gdiff has a rule to run
    mkdir -p "$XDG_CONFIG_HOME/gdiff"
    echo "STAGED TEST RULE" > "$XDG_CONFIG_HOME/gdiff/rule.txt"
}


setup_no_git() {
    mkdir -p "$XDG_CONFIG_HOME/gdiff"
    echo "TEST RULE" > "$XDG_CONFIG_HOME/gdiff/rule.txt"
}


setup_nothing_staged() {
    setup_git_repo
    echo "hello" > myfile.txt
    
    mkdir -p "$XDG_CONFIG_HOME/gdiff"
    echo "TEST RULE" > "$XDG_CONFIG_HOME/gdiff/rule.txt"
}

setup_no_rules_exist() {
    setup_git_repo
    echo "changes" > file.txt
    git add file.txt
    # No user rules, and no default fallback rule
}

setup_restore_rule() {
    mkdir -p "$SANDBOX_DIR/share"
    echo "DEFAULT RULE TEXT" > "$SANDBOX_DIR/share/rule.txt"
}

setup_lazy_init() {
    setup_git_repo
    echo "hello" > myfile.txt
    git add myfile.txt

    mkdir -p "$SANDBOX_DIR/share"
    echo "DEFAULT RULE TEXT" > "$SANDBOX_DIR/share/rule.txt"
}

setup_restore_rule_exists() {
    setup_restore_rule
    mkdir -p "$XDG_CONFIG_HOME/gdiff"
    echo "PRE-EXISTING USER RULE" > "$XDG_CONFIG_HOME/gdiff/rule.txt"
}

setup_local_repo_precedence() {
    setup_git_repo
    echo "changes" > file.txt
    git add file.txt
    
    mkdir -p "$XDG_CONFIG_HOME/gdiff"
    echo "USER RULE" > "$XDG_CONFIG_HOME/gdiff/rule.txt"
}

setup_user_txt_precedence() {
    setup_git_repo
    echo "changes" > file.txt
    git add file.txt

    mkdir -p "$SANDBOX_DIR/share"
    echo "DEFAULT RULE" > "$SANDBOX_DIR/share/rule.txt"

    mkdir -p "$XDG_CONFIG_HOME/gdiff"
    echo "USER TXT RULE" > "$XDG_CONFIG_HOME/gdiff/rule.txt"
    echo "USER MD RULE" > "$XDG_CONFIG_HOME/gdiff/rule.md"
}

setup_user_md_precedence() {
    setup_git_repo
    echo "changes" > file.txt
    git add file.txt

    mkdir -p "$SANDBOX_DIR/share"
    echo "DEFAULT RULE" > "$SANDBOX_DIR/share/rule.txt"

    mkdir -p "$XDG_CONFIG_HOME/gdiff"
    echo "USER MD RULE" > "$XDG_CONFIG_HOME/gdiff/rule.md"
}

setup_custom_rule() {
    setup_git_repo
    echo "changes" > file.txt
    git add file.txt

    echo "SUPER CUSTOM RULE" > "$SANDBOX_DIR/my_custom.txt"
}

setup_empty_rule() {
    setup_git_repo
    echo "changes" > file.txt
    git add file.txt

    mkdir -p "$XDG_CONFIG_HOME/gdiff"
    touch "$XDG_CONFIG_HOME/gdiff/rule.txt"
}

setup_no_clipboard() {
    setup_staged_changes

    rm -f "$SANDBOX_DIR/bin/wl-copy"
    rm -f "$SANDBOX_DIR/bin/xclip"
    rm -f "$SANDBOX_DIR/bin/xsel"
    rm -f "$SANDBOX_DIR/bin/pbcopy"
    rm -f "$SANDBOX_DIR/bin/clip.exe"
}

setup_only_xclip() {
    setup_staged_changes
    rm -f "$SANDBOX_DIR/bin/wl-copy"
    rm -f "$SANDBOX_DIR/bin/xsel"
    rm -f "$SANDBOX_DIR/bin/pbcopy"
    rm -f "$SANDBOX_DIR/bin/clip.exe"
}

setup_only_xsel() {
    setup_staged_changes
    rm -f "$SANDBOX_DIR/bin/wl-copy"
    rm -f "$SANDBOX_DIR/bin/xclip"
    rm -f "$SANDBOX_DIR/bin/pbcopy"
    rm -f "$SANDBOX_DIR/bin/clip.exe"
}

setup_only_pbcopy() {
    setup_staged_changes
    rm -f "$SANDBOX_DIR/bin/wl-copy"
    rm -f "$SANDBOX_DIR/bin/xclip"
    rm -f "$SANDBOX_DIR/bin/xsel"
    rm -f "$SANDBOX_DIR/bin/clip.exe"
}

setup_only_clip() {
    setup_staged_changes
    rm -f "$SANDBOX_DIR/bin/wl-copy"
    rm -f "$SANDBOX_DIR/bin/xclip"
    rm -f "$SANDBOX_DIR/bin/xsel"
    rm -f "$SANDBOX_DIR/bin/pbcopy"
}

setup_no_git_installed() {
    setup_staged_changes
    rm -f "$SANDBOX_DIR/bin/git"
}

setup_lazy_init_md_exists() {
    setup_git_repo
    echo "hello" > myfile.txt
    git add myfile.txt

    mkdir -p "$SANDBOX_DIR/share"
    echo "DEFAULT RULE TEXT" > "$SANDBOX_DIR/share/rule.txt"

    mkdir -p "$XDG_CONFIG_HOME/gdiff"
    echo "PRE-EXISTING MD RULE" > "$XDG_CONFIG_HOME/gdiff/rule.md"
}

setup_failing_clipboard() {
    setup_staged_changes
    # Overwrite mocks to fail
    for cmd in wl-copy xclip xsel pbcopy clip.exe; do
        cat <<EOF > "$SANDBOX_DIR/bin/$cmd"
#!/usr/bin/env bash
exit 1
EOF
        chmod +x "$SANDBOX_DIR/bin/$cmd"
    done
}

# RUNNING TESTS

for SHELL_UNDER_TEST in bash fish; do
    if [ "$SHELL_UNDER_TEST" = "fish" ] && ! command -v fish &>/dev/null; then
        echo -e "\n${YELLOW}Skipping Fish tests because 'fish' interpreter is not installed.${RESET}"
        continue
    fi
    
    print_group_header "$SHELL_UNDER_TEST"
    
    # Help command (-h)
    run_test_case "1a" "Help option (-h)" "setup_none" "copied" "-h" "" 0 "USAGE" "" ""
    run_test_case "1b" "Help option (--help)" "setup_none" "copied" "--help" "" 0 "USAGE" "" ""

    # Version command (-v)
    run_test_case "2a" "Version option (-v)" "setup_none" "copied" "-v" "" 0 "gdiff v1.0.0" "" ""
    run_test_case "2b" "Version option (--version)" "setup_none" "copied" "--version" "" 0 "gdiff v1.0.0" "" ""

    # Outside Git repo
    run_test_case "3" "Run outside Git repository" "setup_no_git" "copied" "" "" 1 "" "Error: Not inside a git repository." ""

    # Nothing staged
    run_test_case "4" "Run with nothing staged in Git" "setup_nothing_staged" "copied" "" "" 1 "" "Nothing staged. Use 'git add' to stage your changes first." ""

    # No rule file found
    run_test_case "5" "No rule file found" "setup_no_rules_exist" "copied" "" "" 1 "" "Error: No rule file found. Run 'gdiff --restore-rule' to create one." ""

    # Restore rule (--restore-rule)
    run_test_case "6a" "Restore default rule (new install)" "setup_restore_rule" "copied" "--restore-rule" "" 0 "Restored default rule to" "" ""
    # Restore rule - overwrite cancelled
    run_test_case "6b" "Restore default rule (exists - cancel)" "setup_restore_rule_exists" "copied" "--restore-rule" "n" 0 "Operation cancelled." "" ""
    # Restore rule - overwrite accepted
    run_test_case "6c" "Restore default rule (exists - overwrite)" "setup_restore_rule_exists" "copied" "--restore-rule" "y" 0 "Restored default rule to" "" ""

    # Lazy initialization of rule
    run_test_case "7" "Lazy initialize config directory & rule file" "setup_lazy_init" "copied" "-p" "" 0 "DEFAULT RULE TEXT" "" ""

    # Rule Precedence
    # Case A: Local repo rule prioritized (original script from its repo location)
    run_test_case "8a" "Precedence: Local development repo rule" "setup_local_repo_precedence" "original" "--rule-path" "" 0 "share/rule.txt" "" ""
    # Case B: User config .txt rule prioritized
    run_test_case "8b" "Precedence: User config rule.txt" "setup_user_txt_precedence" "copied" "--rule-path" "" 0 "gdiff/rule.txt" "" ""
    # Case C: User config .md rule prioritized when .txt is missing
    run_test_case "8c" "Precedence: User config rule.md" "setup_user_md_precedence" "copied" "--rule-path" "" 0 "gdiff/rule.md" "" ""
    # Case D: Custom rule specified via option
    run_test_case "8d" "Precedence: Custom --rule option" "setup_custom_rule" "copied" "--rule $SANDBOX_DIR/my_custom.txt --rule-path" "" 0 "my_custom.txt" "" ""

    # Empty rule file
    run_test_case "9" "Empty rule file error" "setup_empty_rule" "copied" "" "" 1 "" "Error: Rule file is empty" ""

    # Print only mode (-p / --print)
    run_test_case "10" "Print mode output (-p)" "setup_staged_changes" "copied" "-p" "" 0 "STAGED TEST RULE" "" ""

    # Copy to clipboard (Default behavior)
    run_test_case "11" "Copy to clipboard (Default)" "setup_staged_changes" "copied" "" "" 0 "Diff + rule copied to clipboard" "" "STAGED TEST RULE"

    # No clipboard tool found
    run_test_case "12" "Clipboard tool missing" "setup_no_clipboard" "copied" "" "" 1 "" "Error: No clipboard tool found" ""

    # Clipboard tool failure
    run_test_case "13" "Clipboard tool execution failure" "setup_failing_clipboard" "copied" "" "" 1 "" "Error: Failed to copy to clipboard." ""

    # Unknown option and missing arguments
    run_test_case "14a" "Unknown option error" "setup_none" "copied" "--invalid-option" "" 1 "" "Unknown option: '--invalid-option'" ""
    run_test_case "14b" "Missing --rule argument" "setup_none" "copied" "--rule" "" 1 "" "Option '--rule' requires an argument." ""
    run_test_case "14c" "Invalid --rule custom path" "setup_none" "copied" "--rule /tmp/nonexistent_file.txt" "" 1 "" "Error: Rule file not found" ""

    # Missing default rule on restore
    run_test_case "6d" "Restore default rule fails when default rule missing" "setup_no_rules_exist" "copied" "--restore-rule" "" 1 "" "Error: Default rule not found" ""

    # Lazy init precedence with .md
    run_test_case "7b" "Lazy initialize skipped if md rule exists" "setup_lazy_init_md_exists" "copied" "-p" "" 0 "PRE-EXISTING MD RULE" "" ""

    # Alternative Clipboard Tool Fallbacks
    run_test_case "12b" "Clipboard fallback to xclip" "setup_only_xclip" "copied" "" "" 0 "Diff + rule copied to clipboard" "" "STAGED TEST RULE"
    run_test_case "12c" "Clipboard fallback to xsel" "setup_only_xsel" "copied" "" "" 0 "Diff + rule copied to clipboard" "" "STAGED TEST RULE"
    run_test_case "12d" "Clipboard fallback to pbcopy" "setup_only_pbcopy" "copied" "" "" 0 "Diff + rule copied to clipboard" "" "STAGED TEST RULE"
    run_test_case "12e" "Clipboard fallback to clip.exe" "setup_only_clip" "copied" "" "" 0 "Diff + rule copied to clipboard" "" "STAGED TEST RULE"

    # Missing Git command in environment
    run_test_case "15" "Error when git is not installed" "setup_no_git_installed" "copied" "" "" 1 "" "Error: git is not installed." ""

done

# Summary
echo -e "\n${BOLD}======================================================================${RESET}"
echo -e "${BOLD} Tests completed${RESET}"
echo -e "${BOLD}======================================================================${RESET}"
echo -e "  Total Tests Run:  ${BOLD}$TOTAL_TESTS${RESET}"
echo -e "  Passed:          ${GREEN}${BOLD}$PASSED_TESTS${RESET}"
echo -e "  Failed:          $([[ $FAILED_TESTS -gt 0 ]] && echo -e "${RED}${BOLD}$FAILED_TESTS${RESET}" || echo -e "${GREEN}${BOLD}0${RESET}")"
echo -e "${BOLD}======================================================================${RESET}"

if [ $FAILED_TESTS -gt 0 ]; then
    exit 1
fi
exit 0
