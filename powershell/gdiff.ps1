# ==============================================================================
#  gdiff - PowerShell version
#  Port of bash/gdiff for native Windows (PowerShell 5.1+ / PowerShell 7+).
# ==============================================================================

$script:VERSION = "1.2.0"
$script:SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Default rule: repo layout (../share/rule.txt), GDIFF_DEFAULT_RULE, or user config.
# Base directory for gdiff user configuration: %APPDATA%\gdiff on Windows,
# ~/.config/gdiff elsewhere (XDG convention). Falls back gracefully when the
# environment variables are not defined.
$script:USER_CONFIG_DIR = if ($env:APPDATA) {
    Join-Path $env:APPDATA "gdiff"
} elseif ($env:USERPROFILE) {
    Join-Path $env:USERPROFILE ".config\gdiff"
} elseif ($env:HOME) {
    Join-Path $env:HOME ".config/gdiff"
} else {
    Join-Path (Get-Location) ".gdiff"
}
$script:DEFAULT_RULE = $env:GDIFF_DEFAULT_RULE
if (-not $script:DEFAULT_RULE) {
    $repoRule = Join-Path $script:SCRIPT_DIR "..\share\rule.txt"
    $installedDefault = Join-Path $script:SCRIPT_DIR "rule.default.txt"
    if (Test-Path $repoRule) {
        $script:DEFAULT_RULE = (Resolve-Path $repoRule).Path
    } elseif (Test-Path $installedDefault) {
        $script:DEFAULT_RULE = $installedDefault
    }
}

# Global state (filled by Parse-Args)
$script:CustomRule = ""
$script:PrintOnly = $false
$script:ShowRulePath = $false
$script:RestoreRule = $false
$script:DiffOnly = $false
$script:CommitFlag = $false
$script:MessageFlag = $false
$script:Info = $false
$script:Mode = "staged"
$script:CommitTarget = ""
$script:CommitHash = ""
$script:RuleFile = ""
$script:RefShift = 1

# Helpers
function Die {
    param([string]$Message)
    [Console]::Error.WriteLine("Error: $Message")
    exit 1
}

# Message mode never uses a rule; diff-only does not either
function Test-NeedsRule {
    return (-not $script:DiffOnly -and -not $script:MessageFlag)
}

function Show-Help {
    Write-Host "USAGE"
    Write-Host "  gdiff [OPTIONS]"
    Write-Host ""
    Write-Host "OPTIONS"
    Write-Host "  -c, --commit [REF]  Diff of a commit: position, hash or ref (default: 1 = latest)"
    Write-Host "  -m, --message [REF] Print the commit message: position, hash or ref (default: 1 = latest)"
    Write-Host "  -i, --info          With --message: add a header with hash, author and date"
    Write-Host "  -r, --rule <file>   Use a custom rule file (.txt or .md)"
    Write-Host "  -p, --print         Print the output instead of copying to clipboard"
    Write-Host "  -d, --diff-only     Copy only the diff, without the rule"
    Write-Host "  --restore-rule      Restore default rule to $(Join-Path $script:USER_CONFIG_DIR 'rule.txt')"
    Write-Host "  --rule-path         Show which rule file is being used"
    Write-Host "  -v, --version       Show version"
    Write-Host "  -h, --help          Show this help"
    Write-Host ""
    Write-Host "NOTES" -ForegroundColor White
    Write-Host "  --message prints to the terminal, does not use a rule, and cannot be"
    Write-Host "  combined with -c, -r, -p, -d, --restore-rule or --rule-path."
    Write-Host ""
    Write-Host "RULE PRECEDENCE" -ForegroundColor White
    Write-Host "  1. --rule <file>                        (highest)"
    Write-Host "  2. $(Join-Path $script:USER_CONFIG_DIR 'rule.txt')"
    Write-Host "  3. packaged default (share/rule.txt)"
}

function Restore-Rule {
    $configFile = Join-Path $script:USER_CONFIG_DIR "rule.txt"

    if (-not $script:DEFAULT_RULE -or -not (Test-Path $script:DEFAULT_RULE)) {
        [Console]::Error.WriteLine("Error: Default rule not found at $script:DEFAULT_RULE")
        return 1
    }

    if (Test-Path $configFile) {
        $response = Read-Host "Warning: A rule file already exists at $configFile. Overwrite? (y/N)"
        if ($response -notmatch '^(y|yes)$') {
            Write-Host "Operation cancelled."
            return 0
        }
    }

    if (-not (Test-Path $script:USER_CONFIG_DIR)) {
        New-Item -ItemType Directory -Path $script:USER_CONFIG_DIR -Force | Out-Null
    }
    Copy-Item $script:DEFAULT_RULE $configFile -Force
    Write-Host ("{0} Restored default rule to {1} (from {2})" -f [char]0x2713, $configFile, $script:DEFAULT_RULE) -ForegroundColor Green
    return 0
}

function Resolve-Rule {
    param([string]$CustomRule)

    if ($CustomRule) {
        if (-not (Test-Path -LiteralPath $CustomRule -PathType Leaf)) {
            [Console]::Error.WriteLine("Error: Rule file not found: $CustomRule")
            exit 1
        }
        return (Resolve-Path -LiteralPath $CustomRule).Path
    }

    $userRuleTxt = Join-Path $script:USER_CONFIG_DIR "rule.txt"
    $userRuleMd = Join-Path $script:USER_CONFIG_DIR "rule.md"

    # if running from the development repository, prioritize repo's share/rule.txt
    $repoGit = Join-Path $script:SCRIPT_DIR "..\.git"
    $repoRule = Join-Path $script:SCRIPT_DIR "..\share\rule.txt"
    if ((Test-Path $repoGit) -and (Test-Path $repoRule)) {
        return (Resolve-Path $repoRule).Path
    }

    if (Test-Path $userRuleTxt) { return $userRuleTxt }
    if (Test-Path $userRuleMd) { return $userRuleMd }

    if ($script:DEFAULT_RULE -and (Test-Path $script:DEFAULT_RULE)) {
        return $script:DEFAULT_RULE
    }

    [Console]::Error.WriteLine("Error: No rule file found. Run 'gdiff --restore-rule' to create one.")
    exit 1
}

function Invoke-LazyInit {
    $configFile = Join-Path $script:USER_CONFIG_DIR "rule.txt"
    $configFileMd = Join-Path $script:USER_CONFIG_DIR "rule.md"

    if ((-not (Test-Path $configFile)) -and (-not (Test-Path $configFileMd)) `
            -and $script:DEFAULT_RULE -and (Test-Path $script:DEFAULT_RULE)) {
        New-Item -ItemType Directory -Path $script:USER_CONFIG_DIR -Force | Out-Null
        Copy-Item $script:DEFAULT_RULE $configFile -Force
    }
}

#  Mode: staged 
function Assert-Staged {
    git diff --cached --quiet 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        [Console]::Error.WriteLine("Nothing staged. Use 'git add' to stage your changes first.")
        exit 1
    }
}

function Get-StagedDiff {
    git diff --cached --stat
    ""
    git diff --cached
}

# Mode: commit 
# Returns the resolved commit hash; errors go to stderr and exit the script.
function Resolve-Commit {
    param([string]$CommitTarget)

    git rev-parse --verify HEAD 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("Error: No commits found in repository.")
        exit 1
    }

    if ($CommitTarget -match '^[0-9]{1,6}$') {
        # Short all-digit values are positions in git log order, counting from
        # HEAD. Every reachable commit counts, including merge commits and the
        # commits of merged branches.
        if ($CommitTarget -notmatch '^[1-9][0-9]*$') {
            [Console]::Error.WriteLine("Error: Invalid commit position '$CommitTarget'. Must be a positive integer (e.g. 1, 2, 3).")
            exit 1
        }

        $totalCommitsStr = git rev-list --count HEAD 2>$null
        $totalCommits = 0
        if ([int]::TryParse($totalCommitsStr, [ref]$totalCommits)) {
            $targetNum = [int]$CommitTarget
            if ($targetNum -gt $totalCommits) {
                $commitNoun = if ($totalCommits -eq 1) { "commit" } else { "commits" }
                [Console]::Error.WriteLine("Error: Commit at position $CommitTarget does not exist (branch only has $totalCommits $commitNoun).")
                exit 1
            }
        }

        $skip = ([int]$CommitTarget) - 1
        $commitHash = (git rev-list --skip="$skip" --max-count=1 HEAD 2>$null)
        if (-not $commitHash) {
            [Console]::Error.WriteLine("Error: Failed to resolve commit at position $CommitTarget.")
            exit 1
        }
    } else {
        # Anything else is treated as a hash or ref
        if ([string]::IsNullOrEmpty($CommitTarget) -or $CommitTarget.StartsWith('-')) {
            [Console]::Error.WriteLine("Error: Invalid commit '$CommitTarget'. Use a position (e.g. 1, 2, 3) or a commit hash.")
            exit 1
        }

        $commitHash = (git rev-parse --verify --quiet "$CommitTarget^{commit}" 2>$null)
        if (-not $commitHash) {
            [Console]::Error.WriteLine("Error: Commit '$CommitTarget' not found.")
            exit 1
        }
    }

    return $commitHash
}

function Get-CommitDiff {
    param([string]$CommitHash)

    git show -m --first-parent --stat --format="" $CommitHash
    ""
    git show -m --first-parent -p --format="" $CommitHash
}

# Mode: message
# Prints the commit message exactly as it was written, without indentation.
# With WithInfo=true, a header (hash, short hash, author, date) goes first.
function Show-CommitMessage {
    param(
        [string]$CommitHash,
        [bool]$WithInfo
    )

    $message = (git log -1 --format=%B $CommitHash) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        exit 1
    }

    if ($WithInfo) {
        git log -1 --date=default `
            --format="Commit: %H%nShort:  %h%nAuthor: %an <%ae>%nDate:   %ad" `
            $CommitHash
        if ($LASTEXITCODE -ne 0) {
            exit 1
        }
        ""
    }

    # Command substitution in bash strips trailing newlines; mirror that so the
    # message ends with exactly one newline.
    Write-Output $message.TrimEnd("`r", "`n")
}

# Output
# Emits the diff of the active mode followed by the rule (if any), line by line.
function Get-GdiffContent {
    switch ($script:Mode) {
        'staged' { Get-StagedDiff }
        'commit' { Get-CommitDiff -CommitHash $script:CommitHash }
    }
    ""
    ""
    if (Test-NeedsRule) {
        Get-Content $script:RuleFile
    }
}

# Argument parsing

# If the next argument looks like a ref (not an option), consume it.
# $Tokens[$Index] is the flag itself; $Tokens[$Index + 1] the candidate ref.
function Parse-RefArg {
    param(
        [string[]]$Tokens,
        [int]$Index
    )

    if (($Index + 1) -lt $Tokens.Count) {
        $nextArg = "$($Tokens[$Index + 1])"
        if (($nextArg -notmatch '^-') -or ($nextArg -match '^-[0-9]+$')) {
            $script:CommitTarget = $nextArg
            $script:RefShift = 2
            return
        }
    }

    $script:CommitTarget = "1"
    $script:RefShift = 1
}

function Parse-Args {
    param([string[]]$Tokens)

    $i = 0
    while ($i -lt $Tokens.Count) {
        $arg = "$($Tokens[$i])"
        switch -Regex ($arg) {
            '^(--commit|-c)$' {
                $script:Mode = "commit"
                $script:CommitFlag = $true
                Parse-RefArg -Tokens $Tokens -Index $i
                $i += $script:RefShift
                continue
            }
            '^--commit=(.*)$' {
                $script:Mode = "commit"
                $script:CommitFlag = $true
                $script:CommitTarget = $Matches[1]
                $i++
                continue
            }
            '^(--message|-m)$' {
                $script:Mode = "message"
                $script:MessageFlag = $true
                Parse-RefArg -Tokens $Tokens -Index $i
                $i += $script:RefShift
                continue
            }
            '^--message=(.*)$' {
                $script:Mode = "message"
                $script:MessageFlag = $true
                $script:CommitTarget = $Matches[1]
                $i++
                continue
            }
            '^(--info|-i)$' { $script:Info = $true; $i++; continue }
            '^(--rule|-r)$' {
                if ($i -ge ($Tokens.Count - 1)) {
                    Die "Option '$arg' requires an argument."
                }
                $script:CustomRule = "$($Tokens[$i + 1])"
                $i += 2
                continue
            }
            '^(--print|-p)$' { $script:PrintOnly = $true; $i++; continue }
            '^(--diff-only|-d)$' { $script:DiffOnly = $true; $i++; continue }
            '^--restore-rule$' { $script:RestoreRule = $true; $i++; continue }
            '^--rule-path$' { $script:ShowRulePath = $true; $i++; continue }
            '^(--version|-v)$' { Write-Host "gdiff v$script:VERSION"; exit 0 }
            '^(--help|-h)$' { Show-Help; exit 0 }
            default {
                [Console]::Error.WriteLine("Unknown option: '$arg'")
                [Console]::Error.WriteLine("  Run 'gdiff --help' for a list of valid options.")
                exit 1
            }
        }
    }
}

# Validate flag combinations before doing anything
function Assert-Flags {
    if ($script:MessageFlag) {
        $conflicts = @()
        if ($script:CommitFlag) { $conflicts += "--commit" }
        if ($script:CustomRule) { $conflicts += "--rule" }
        if ($script:PrintOnly) { $conflicts += "--print" }
        if ($script:DiffOnly) { $conflicts += "--diff-only" }
        if ($script:RestoreRule) { $conflicts += "--restore-rule" }
        if ($script:ShowRulePath) { $conflicts += "--rule-path" }

        if ($conflicts.Count -gt 0) {
            Die ("--message cannot be combined with {0}." -f ($conflicts -join ", "))
        }
    }

    if ($script:Info -and -not $script:MessageFlag) {
        Die "--info can only be used with --message."
    }
}

# Setup steps used by Main

# Message mode never uses a rule; diff-only does not either
function Select-Rule {
    if (-not (Test-NeedsRule)) { return }
    $script:RuleFile = Resolve-Rule -CustomRule $script:CustomRule
}

function Assert-RuleFile {
    if (-not (Test-NeedsRule)) { return }
    Invoke-LazyInit
    if (-not (Test-Path $script:RuleFile) -or (Get-Item $script:RuleFile).Length -eq 0) {
        [Console]::Error.WriteLine("Error: Rule file is empty: $($script:RuleFile)")
        [Console]::Error.WriteLine("Please edit the file or run 'gdiff --restore-rule' to restore the default rule.")
        exit 1
    }
}

function Assert-Environment {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Die "git is not installed."
    }

    git rev-parse --git-dir 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Die "Not inside a git repository."
    }
}

function Resolve-Target {
    switch ($script:Mode) {
        'staged' { Assert-Staged }
        'commit' { $script:CommitHash = Resolve-Commit -CommitTarget $script:CommitTarget }
        'message' { $script:CommitHash = Resolve-Commit -CommitTarget $script:CommitTarget }
    }
}

function Send-GdiffOutput {
    if ($script:PrintOnly) {
        Get-GdiffContent
        return
    }

    $content = @(Get-GdiffContent) -join "`n"

    try {
        Set-Clipboard -Value $content -ErrorAction Stop
    } catch {
        [Console]::Error.WriteLine("Error: Failed to copy to clipboard.")
        [Console]::Error.WriteLine($_.Exception.Message)
        [Console]::Error.WriteLine("Use --print to output to stdout instead.")
        exit 1
    }

    if ($script:DiffOnly) {
        Write-Host ("{0} Diff copied to clipboard" -f [char]0x2713) -ForegroundColor Green
    } else {
        Write-Host ("{0} Diff + rule copied to clipboard" -f [char]0x2713) -ForegroundColor Green
    }
    exit 0
}

# Entry point
function Main {
    Parse-Args -Tokens $args
    Assert-Flags

    if ($script:RestoreRule) {
        exit (Restore-Rule)
    }

    Select-Rule
    if ($script:ShowRulePath) {
        Write-Output $script:RuleFile
        exit 0
    }
    Assert-RuleFile

    Assert-Environment
    Resolve-Target

    if ($script:Mode -eq 'message') {
        Show-CommitMessage -CommitHash $script:CommitHash -WithInfo $script:Info
        exit 0
    }

    Send-GdiffOutput
}

Main @args