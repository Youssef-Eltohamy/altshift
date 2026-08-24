#Requires -Version 5.1
<#
    AltShift installer.

    Run from a local clone:      .\install.ps1
    Or straight from GitHub:     irm https://raw.githubusercontent.com/Youssef-Eltohamy/altshift/main/install.ps1 | iex

    Everything it does is local: installs AutoHotkey v2 (via winget) if missing,
    copies the script to %LOCALAPPDATA%\AltShift, adds a Startup shortcut, runs it.
#>
[CmdletBinding()]
param(
    [string]$Dest    = "$env:LOCALAPPDATA\AltShift",
    [string]$RepoRaw = "https://raw.githubusercontent.com/Youssef-Eltohamy/altshift/main",
    [switch]$NoStartup,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'

function Find-Ahk {
    @(
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey32.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

# --- 1. AutoHotkey v2 --------------------------------------------------
$ahk = Find-Ahk
if (-not $ahk) {
    Write-Host "AutoHotkey v2 not found. Installing with winget..." -ForegroundColor Yellow
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget is not available. Install AutoHotkey v2 manually from https://www.autohotkey.com then re-run this script."
    }
    winget install --id AutoHotkey.AutoHotkey -e --accept-source-agreements --accept-package-agreements --silent
    $ahk = Find-Ahk
    if (-not $ahk) { throw "AutoHotkey v2 still not found after install." }
}
Write-Host "AutoHotkey : $ahk" -ForegroundColor Green

# --- 2. files ----------------------------------------------------------
New-Item -ItemType Directory -Force -Path $Dest, (Join-Path $Dest 'assets') | Out-Null
$files  = 'AltShift.ahk', 'AltShift.test.ahk', 'settings.ini.example', 'assets/altshift.ico'
$srcDir = $PSScriptRoot

foreach ($f in $files) {
    $rel    = $f -replace '/', '\'
    $target = Join-Path $Dest $rel
    $local  = if ($srcDir) { Join-Path $srcDir $rel } else { $null }
    if ($local -and (Test-Path $local)) {
        Copy-Item $local $target -Force
    } else {
        Invoke-WebRequest "$RepoRaw/$f" -OutFile $target -UseBasicParsing
    }
}
Write-Host "Installed to : $Dest" -ForegroundColor Green

# --- 3. settings (never overwrite an existing one) ---------------------
$ini = Join-Path $Dest 'settings.ini'
if (-not (Test-Path $ini)) {
    Copy-Item (Join-Path $Dest 'settings.ini.example') $ini
    Write-Host "Settings   : $ini (defaults)" -ForegroundColor Green
} else {
    Write-Host "Settings   : $ini (kept your existing file)" -ForegroundColor Green
}

# --- 4. run at login ---------------------------------------------------
if (-not $NoStartup) {
    $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'AltShift.lnk'
    $s   = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    $s.TargetPath       = $ahk
    $s.Arguments        = '"' + (Join-Path $Dest 'AltShift.ahk') + '"'
    $s.WorkingDirectory = $Dest
    $s.IconLocation     = (Join-Path $Dest 'assets\altshift.ico')
    $s.Description      = 'AltShift - fix wrong-keyboard-layout text'
    $s.Save()
    Write-Host "Startup    : $lnk" -ForegroundColor Green
}

# --- 5. launch ---------------------------------------------------------
if (-not $NoLaunch) {
    Start-Process $ahk -ArgumentList ('"' + (Join-Path $Dest 'AltShift.ahk') + '"')
    Write-Host ""
    Write-Host "Running. Select some wrongly-typed text and press Ctrl+Alt+X." -ForegroundColor Cyan
    Write-Host "Right-click the tray icon for the menu." -ForegroundColor Cyan
}
