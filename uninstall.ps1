#Requires -Version 5.1
<#
    AltShift uninstaller - removes everything install.ps1 created, including settings.ini.

    irm https://raw.githubusercontent.com/Youssef-Eltohamy/altshift/main/uninstall.ps1 | iex
#>
[CmdletBinding()]
param(
    [string]$Dest = "$env:LOCALAPPDATA\AltShift"
)

$ErrorActionPreference = 'Stop'

Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" |
    Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($Dest, [StringComparison]::OrdinalIgnoreCase) -ge 0 } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 300

# Only remove the Startup shortcut if it points into $Dest - never someone else's copy.
$lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'AltShift.lnk'
if (Test-Path $lnk) {
    $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    if ($sc.Arguments.IndexOf($Dest, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        Remove-Item $lnk -Force
        Write-Host "  Removed $lnk" -ForegroundColor Green
    } else {
        Write-Host "  Kept $lnk (it points elsewhere)" -ForegroundColor Yellow
    }
}
if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force; Write-Host "  Removed $Dest" -ForegroundColor Green }

Write-Host "AltShift is gone. Nothing else on the machine was touched." -ForegroundColor Cyan
