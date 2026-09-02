#Requires -Version 5.1
<#
    AltShift installer.

    From a local clone:        .\install.ps1
    Straight from GitHub:      irm https://raw.githubusercontent.com/Youssef-Eltohamy/altshift/main/install.ps1 | iex
    With options:              & ([scriptblock]::Create((irm <same url>))) -NoStartup

    Everything stays on your machine and needs no admin rights:
      1. downloads a pinned, checksum-verified portable AutoHotkey v2 into %LOCALAPPDATA%\AltShift\ahk
      2. copies the AltShift script next to it and runs its self-test
      3. adds a Startup shortcut (-NoStartup to skip) and launches it (-NoLaunch to skip)

    Uninstall:                 irm https://raw.githubusercontent.com/Youssef-Eltohamy/altshift/main/uninstall.ps1 | iex
#>
[CmdletBinding()]
param(
    [string]$Dest    = "$env:LOCALAPPDATA\AltShift",
    [string]$RepoRaw = "https://raw.githubusercontent.com/Youssef-Eltohamy/altshift/main",
    [switch]$NoStartup,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 on older Windows 10 builds still defaults to TLS 1.0, which GitHub rejects.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Pinned AutoHotkey release. Bump both lines together; the hash is of the release zip.
$AhkVersion = '2.0.27'
$AhkSha256  = 'f72cad4b98a7b5aa050b35d6deaa0b0e3949929b2aaff7d0d69858f1f380b3ef'
$AhkUrl     = "https://github.com/AutoHotkey/AutoHotkey/releases/download/v$AhkVersion/AutoHotkey_$AhkVersion.zip"

$ahkDir = Join-Path $Dest 'ahk'
$ahkExe = Join-Path $ahkDir $(if ([Environment]::Is64BitOperatingSystem) { 'AutoHotkey64.exe' } else { 'AutoHotkey32.exe' })
$stamp  = Join-Path $ahkDir 'VERSION'
$script = Join-Path $Dest 'AltShift.ahk'

function Step($msg) { Write-Host "  $msg" -ForegroundColor Green }

Write-Host ""
Write-Host "AltShift installer" -ForegroundColor Cyan

# --- 0. stop a running copy so its files can be replaced ---------------
Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" |
    Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($script, [StringComparison]::OrdinalIgnoreCase) -ge 0 } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# --- 1. portable AutoHotkey v2 (pinned version, checksum-verified) ------
$have = (Test-Path $ahkExe) -and (Test-Path $stamp) -and ((Get-Content $stamp -Raw -ErrorAction SilentlyContinue) -eq $AhkVersion)
if ($have) {
    Step "AutoHotkey : v$AhkVersion already in $ahkDir"
} else {
    Step "AutoHotkey : downloading v$AhkVersion (portable, ~3 MB)..."
    $zip = Join-Path ([IO.Path]::GetTempPath()) "AutoHotkey_$AhkVersion.zip"
    Invoke-WebRequest $AhkUrl -OutFile $zip -UseBasicParsing
    $got = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
    if ($got -ne $AhkSha256) {
        Remove-Item $zip -Force
        throw "AutoHotkey download did not match its pinned checksum (expected $AhkSha256, got $got). Nothing was installed."
    }
    if (Test-Path $ahkDir) { Remove-Item $ahkDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $ahkDir | Out-Null
    Expand-Archive $zip -DestinationPath $ahkDir -Force
    Remove-Item $zip -Force
    if (-not (Test-Path $ahkExe)) { throw "The AutoHotkey archive did not contain $(Split-Path $ahkExe -Leaf)." }
    # keep only what the tool needs: the interpreters and their licence
    Get-ChildItem $ahkDir | Where-Object { $_.Name -notin 'AutoHotkey64.exe', 'AutoHotkey32.exe', 'license.txt' } |
        Remove-Item -Recurse -Force
    Set-Content $stamp $AhkVersion -NoNewline
    Step "AutoHotkey : v$AhkVersion -> $ahkDir"
}

# --- 2. AltShift files -------------------------------------------------
New-Item -ItemType Directory -Force -Path $Dest, (Join-Path $Dest 'assets') | Out-Null
$files = 'AltShift.ahk', 'AltShift.test.ahk', 'settings.ini.example', 'assets/altshift.ico'
foreach ($f in $files) {
    $rel    = $f -replace '/', '\'
    $target = Join-Path $Dest $rel
    $local  = if ($PSScriptRoot) { Join-Path $PSScriptRoot $rel } else { $null }
    if ($local -and (Test-Path $local)) {
        Copy-Item $local $target -Force
    } else {
        Invoke-WebRequest "$RepoRaw/$f" -OutFile $target -UseBasicParsing
    }
}
# Clear mark-of-the-web on everything we downloaded, or SmartScreen prompts on first launch.
Get-ChildItem $Dest -Recurse -File | Unblock-File
Step "Files      : $Dest"

# --- 3. settings (never overwrite an existing one) ---------------------
$ini = Join-Path $Dest 'settings.ini'
if (-not (Test-Path $ini)) {
    Copy-Item (Join-Path $Dest 'settings.ini.example') $ini
    Step "Settings   : $ini (defaults)"
} else {
    Step "Settings   : $ini (kept your existing file)"
}

# --- 4. self-test: prove the interpreter runs and the maps are intact ---
$log = Join-Path ([IO.Path]::GetTempPath()) 'altshift-selftest.log'
$p = Start-Process $ahkExe -ArgumentList "`"$script`"", '--selftest' -Wait -PassThru -NoNewWindow -RedirectStandardOutput $log
if ($p.ExitCode -ne 0) {
    Get-Content $log -ErrorAction SilentlyContinue | Write-Host
    throw "AltShift self-test failed ($($p.ExitCode) assertion(s)). Please open an issue: https://github.com/Youssef-Eltohamy/altshift/issues"
}
Remove-Item $log -Force -ErrorAction SilentlyContinue
Step "Self-test  : passed"

# --- 5. run at login ---------------------------------------------------
if (-not $NoStartup) {
    $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'AltShift.lnk'
    $s   = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    $s.TargetPath       = $ahkExe
    $s.Arguments        = '"' + $script + '"'
    $s.WorkingDirectory = $Dest
    $s.IconLocation     = (Join-Path $Dest 'assets\altshift.ico')
    $s.Description      = 'AltShift - fix wrong-keyboard-layout text'
    $s.Save()
    Step "Startup    : $lnk"
}

# --- 6. launch ---------------------------------------------------------
if (-not $NoLaunch) {
    Start-Process $ahkExe -ArgumentList ('"' + $script + '"') -WorkingDirectory $Dest
    Write-Host ""
    Write-Host "Running. Select some wrongly-typed text and press Ctrl+Alt+X." -ForegroundColor Cyan
    Write-Host "Right-click the tray icon for the menu." -ForegroundColor Cyan
}
