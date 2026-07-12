<#
.SYNOPSIS
    Vivaldi Swift — Windows Uninstaller

.DESCRIPTION
    Restores the most recent window.html backup for the detected Vivaldi
    installation, removes the Task Scheduler task, and optionally deletes
    %USERPROFILE%\Vivaldi-Swift.

.PARAMETER Yes
    Non-interactive mode (auto-confirm all prompts).

.PARAMETER Purge
    Also delete the Vivaldi-Swift directory after restoring.

.EXAMPLE
    .\uninstall-windows.ps1

.EXAMPLE
    .\uninstall-windows.ps1 -Yes -Purge
#>

[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$Purge
)

$ErrorActionPreference = "Stop"

$ModDir   = "$env:USERPROFILE\Vivaldi-Swift"
$TaskName = "VivaldiSwiftPatch"

function Info { param($m) Write-Host "-> $m" }
function Ok   { param($m) Write-Host "OK $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "!  $m" -ForegroundColor Yellow }

Write-Host "======================================"
Write-Host " Vivaldi Swift - Windows Uninstaller"
Write-Host "======================================"
Write-Host ""

# ------------------------------------------------------------------------
# 1. Locate Vivaldi and restore window.html
# ------------------------------------------------------------------------
$Roots = @(
    "$env:ProgramFiles\Vivaldi",
    "${env:ProgramFiles(x86)}\Vivaldi",
    "$env:LocalAppData\Vivaldi"
)

$VivaldiDir = $null
foreach ($root in $Roots) {
    $appRoot = Join-Path $root "Application"
    if (-not (Test-Path $appRoot)) { continue }

    $versionDirs = Get-ChildItem -Path $appRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    foreach ($v in $versionDirs) {
        $candidate = Join-Path $v.FullName "resources\vivaldi"
        if (Test-Path (Join-Path $candidate "window.html")) {
            $VivaldiDir = $candidate
            break
        }
    }
    if ($VivaldiDir) { break }
}

if (-not $VivaldiDir) {
    Warn "Vivaldi installation not found; skipping window.html restoration."
} else {
    $backupDir = Join-Path $ModDir "backups\windows"
    $latestBackup = Get-ChildItem -Path $backupDir -Filter "window.html-*" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1

    $windowHtml = Join-Path $VivaldiDir "window.html"

    if (-not $latestBackup) {
        Warn "No backup found; removing injected tags manually instead."
        try {
            $content = Get-Content -Path $windowHtml -Raw
            $content = $content -replace '<link rel="stylesheet" href="vivaldi_swift.css">', ''
            $content = $content -replace '<script src="custom.js"></script>', ''
            Set-Content -Path $windowHtml -Value $content -NoNewline -Encoding utf8
        } catch {
            Warn "Could not clean window.html: $($_.Exception.Message)"
        }
    } else {
        Info "Restoring window.html from $($latestBackup.FullName)"
        try {
            Copy-Item -Path $latestBackup.FullName -Destination $windowHtml -Force
            Ok "Restored $windowHtml"
        } catch {
            Warn "Failed to restore window.html: $($_.Exception.Message)"
        }
    }

    Remove-Item -Path (Join-Path $VivaldiDir "vivaldi_swift.css") -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $VivaldiDir "custom.js") -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------------
# 2. Remove Task Scheduler task
# ------------------------------------------------------------------------
Info "Removing scheduled task..."
try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Ok "Scheduled task removed."
} catch {
    Warn "Could not remove scheduled task (it may not exist)."
}

# ------------------------------------------------------------------------
# 3. Optionally purge the install directory
# ------------------------------------------------------------------------
if ($Purge) {
    $doPurge = $true
    if (-not $Yes) {
        $answer = Read-Host "Delete $ModDir entirely, including logs and backups? [y/N]"
        if ($answer -notmatch '^[Yy]') {
            Info "Skipping directory removal."
            $doPurge = $false
        }
    }
    if ($doPurge) {
        Remove-Item -Path $ModDir -Recurse -Force -ErrorAction SilentlyContinue
        Ok "Removed $ModDir"
    }
} else {
    Info "$ModDir left in place (logs/backups preserved). Use -Purge to remove it."
}

Write-Host ""
Ok "Vivaldi Swift uninstalled. Restart Vivaldi to see the original UI."
