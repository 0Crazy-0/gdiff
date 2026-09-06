# ==============================================================================
#  gdiff Windows installer (PowerShell)
#
#  Usage (from any PowerShell on Windows 10/11):
#    irm https://raw.githubusercontent.com/0Crazy-0/gdiff/main/windows-setup.ps1 | iex
#
#  - Downloads the PowerShell port (powershell/gdiff.ps1) and the default rule
#    straight from this repository.
#  - Installs into ~\.gdiff and adds it to the user PATH.
#  - Idempotent: re-running it updates gdiff. Your custom rule file
#    (%APPDATA%\gdiff\rule.txt) is never overwritten.
# ==============================================================================

$ErrorActionPreference = 'Stop'

$RawBase = 'https://raw.githubusercontent.com/0Crazy-0/gdiff/main'
$InstallDir = Join-Path $env:USERPROFILE '.gdiff'
$UserConfigDir = Join-Path $env:APPDATA 'gdiff'

function Ohai { param([string]$Message) Write-Host "==> $Message" }

# --- 1. Prepare install directory -------------------------------------------
Ohai "Creating install directory: $InstallDir"
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# --- 2. Download the script and default rule ---------------------------------
# Both files are downloaded straight to their final destination: no temp
# files to clean up if something fails mid-way.
Ohai "Downloading gdiff (PowerShell script + default rule)"
try {
    Invoke-WebRequest -Uri "$RawBase/powershell/gdiff.ps1" -OutFile (Join-Path $InstallDir 'gdiff.ps1') -UseBasicParsing
    Invoke-WebRequest -Uri "$RawBase/share/rule.txt" -OutFile (Join-Path $InstallDir 'rule.default.txt') -UseBasicParsing
} catch {
    Write-Host "Download Error!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Ensure LF line endings (PowerShell handles both, but git diffs look cleaner)
$gdiffPath = Join-Path $InstallDir 'gdiff.ps1'
$content = Get-Content $gdiffPath -Raw
[System.IO.File]::WriteAllText($gdiffPath, $content.Replace("`r`n", "`n"))

# --- 3. Install the default rule (never overwrite user config) ---------------
$defaultRulePath = Join-Path $InstallDir 'rule.default.txt'
$userRulePath = Join-Path $UserConfigDir 'rule.txt'

if (Test-Path $userRulePath) {
    Ohai "Existing user rule found at $userRulePath (left untouched)"
} else {
    Ohai "Installing default rule to $userRulePath"
    if (-not (Test-Path $UserConfigDir)) {
        New-Item -ItemType Directory -Path $UserConfigDir -Force | Out-Null
    }
    Copy-Item $defaultRulePath $userRulePath
}

# --- 4. Add install dir to the user PATH if missing --------------------------
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$InstallDir*") {
    Ohai "Adding $InstallDir to your user PATH"
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$InstallDir", 'User')
    $env:Path = "$env:Path;$InstallDir"
} else {
    Ohai "$InstallDir is already on your PATH"
}

# --- 5. Shim: bare `gdiff` command -------------------------------------------
#    A tiny wrapper so `gdiff` works without typing `gdiff.ps1` and without
#    ExecutionPolicy issues (dot-sourcing a local script is always allowed).
#    Recreated on every install, so switching between Windows PowerShell and
#    pwsh (PowerShell 7+) is picked up automatically on re-runs.
$shimPath = Join-Path $InstallDir 'gdiff.cmd'
$psHost = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
Ohai "Creating gdiff.cmd shim (using $psHost)"
$shim = @"
@echo off
$psHost -NoProfile -ExecutionPolicy Bypass -File "%~dp0gdiff.ps1" %*
"@
Set-Content -Path $shimPath -Value $shim -Encoding ASCII

Write-Host ""
Ohai "gdiff installed successfully!"
Write-Host ""
Write-Host "Open a NEW terminal and run:" -ForegroundColor White
Write-Host "  gdiff --help"
Write-Host ""
Write-Host "To restore the default rule at any time:" -ForegroundColor White
Write-Host "  gdiff --restore-rule"
Write-Host ""
Write-Host "Note: re-running this installer updates gdiff without touching your" -ForegroundColor DarkGray
Write-Host "custom rules at $userRulePath" -ForegroundColor DarkGray