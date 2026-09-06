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

function Show-Help {
    Write-Host "USAGE"
    Write-Host "  gdiff [OPTIONS]"
    Write-Host ""
    Write-Host "OPTIONS"
    Write-Host "  -r, --rule <file>   Use a custom rule file (.txt or .md)"
    Write-Host "  -p, --print         Print the output instead of copying to clipboard"
    Write-Host "  -d, --diff-only     Copy only the diff, without the rule"
    Write-Host "  --restore-rule      Restore default rule to $(Join-Path $script:USER_CONFIG_DIR 'rule.txt')"
    Write-Host "  --rule-path         Show which rule file is being used"
    Write-Host "  -v, --version       Show version"
    Write-Host "  -h, --help          Show this help"
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
function Main {
    $customRule = ""
    $printOnly = $false
    $showRulePath = $false
    $diffOnly = $false

    $i = 0
    while ($i -lt $args.Count) {
        $arg = "$($args[$i])"
        switch -Regex ($arg) {
            '^(--rule|-r)$' {
                if ($i -ge ($args.Count - 1)) {
                    [Console]::Error.WriteLine("Error: Option '$arg' requires an argument.")
                    exit 1
                }
                $customRule = "$($args[$i + 1])"
                $i += 2
                continue
            }
            '^(--print|-p)$' { $printOnly = $true; $i++; continue }
            '^(--diff-only|-d)$' { $diffOnly = $true; $i++; continue }
            '^--restore-rule$' { exit (Restore-Rule) }
            '^--rule-path$' { $showRulePath = $true; $i++; continue }
            '^(--version|-v)$' { Write-Host "gdiff v$script:VERSION"; exit 0 }
            '^(--help|-h)$' { Show-Help; exit 0 }
            default {
                [Console]::Error.WriteLine("Unknown option: '$arg'")
                [Console]::Error.WriteLine("  Run 'gdiff --help' for a list of valid options.")
                exit 1
            }
        }
    }

    $ruleFile = ""
    if (-not $diffOnly) {
        $ruleFile = Resolve-Rule -CustomRule $customRule
    }

    if ($showRulePath) {
        Write-Output $ruleFile
        exit 0
    }

    if (-not $diffOnly) {
        Invoke-LazyInit
        if (-not (Test-Path $ruleFile) -or (Get-Item $ruleFile).Length -eq 0) {
            [Console]::Error.WriteLine("Error: Rule file is empty: $ruleFile")
            [Console]::Error.WriteLine("Please edit the file or run 'gdiff --restore-rule' to restore the default rule.")
            exit 1
        }
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine("Error: git is not installed.")
        exit 1
    }

    git rev-parse --git-dir 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("Error: Not inside a git repository.")
        exit 1
    }

    git diff --cached --quiet 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        [Console]::Error.WriteLine("Nothing staged. Use 'git add' to stage your changes first.")
        exit 1
    }

    if ($printOnly) {
        git diff --cached --stat
        Write-Output ""
        git diff --cached
        Write-Output ""
        Write-Output ""
        if (-not $diffOnly) {
            Get-Content $ruleFile
        }
        exit 0
    }

    $content = @(
        git diff --cached --stat
        ""
        git diff --cached
        ""
        ""
        if (-not $diffOnly) {
            Get-Content $ruleFile
        }
    ) -join "`n"

    try {
        Set-Clipboard -Value $content -ErrorAction Stop
    } catch {
        [Console]::Error.WriteLine("Error: Failed to copy to clipboard.")
        [Console]::Error.WriteLine($_.Exception.Message)
        [Console]::Error.WriteLine("Use --print to output to stdout instead.")
        exit 1
    }

    if ($diffOnly) {
        Write-Host ("{0} Diff copied to clipboard" -f [char]0x2713) -ForegroundColor Green
    } else {
        Write-Host ("{0} Diff + rule copied to clipboard" -f [char]0x2713) -ForegroundColor Green
    }
    exit 0
}

Main @args