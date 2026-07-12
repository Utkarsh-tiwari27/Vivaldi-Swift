<#
.SYNOPSIS
    Vivaldi Swift — Windows Updater

.DESCRIPTION
    Updates an existing Vivaldi Swift install in place, without a manual
    ZIP download: fetches the latest GitHub Release, replaces the
    CSS/JS/patch engine, and reapplies the patch. User icons, logs, and
    backups are left untouched.

.PARAMETER Yes
    Non-interactive mode (auto-confirm all prompts).

.EXAMPLE
    .\update-windows.ps1

.EXAMPLE
    .\update-windows.ps1 -Yes
#>

[CmdletBinding()]
param(
    [switch]$Yes
)

$ErrorActionPreference = "Stop"

# Placeholder org/repo — matches the rest of the project until it's
# published under its real GitHub location.
$Repo = "vivaldi-swift/vivaldi-swift"
$ReleaseBase = "https://github.com/$Repo/releases/latest/download"

$ModDir = "$env:USERPROFILE\Vivaldi-Swift"

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Info { param($m) Write-Host "  $m" }
function Ok   { param($m) Write-Host "✓ $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "! $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "✗ $m" -ForegroundColor Red; exit 1 }

Write-Host "──────────────────────────────"
Write-Host " Vivaldi Swift Updater"
Write-Host "──────────────────────────────"

if (-not (Test-Path $ModDir)) {
    Fail "Vivaldi Swift is not installed ($ModDir not found). Run install-windows.ps1 first."
}

# ------------------------------------------------------------------------
# Compare local vs. remote version.json — no need to download the full
# release archive just to find out an update isn't needed.
# ------------------------------------------------------------------------
$localVersion = "unknown"
$localVersionFile = Join-Path $ModDir "version.json"
if (Test-Path $localVersionFile) {
    try {
        $localVersion = (Get-Content $localVersionFile -Raw | ConvertFrom-Json).version
    } catch { $localVersion = "unknown" }
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vivaldi-swift-update-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

try {
    $remoteVersionFile = Join-Path $workDir "version.json"
    try {
        Invoke-WebRequest -Uri "$ReleaseBase/version.json" -OutFile $remoteVersionFile -UseBasicParsing
    } catch {
        Fail "Could not reach GitHub Releases for $Repo. Check your connection and the `$Repo placeholder in this script."
    }

    $remoteVersion = "unknown"
    try {
        $remoteVersion = (Get-Content $remoteVersionFile -Raw | ConvertFrom-Json).version
    } catch { $remoteVersion = "unknown" }

    Info "Installed version : $localVersion"
    Info "Latest version     : $remoteVersion"

    if ($localVersion -eq $remoteVersion -and $remoteVersion -ne "unknown") {
        Ok "Already up to date (v$localVersion)."
        exit 0
    }

    # --------------------------------------------------------------------
    # Download and extract the latest release
    # --------------------------------------------------------------------
    $archive = Join-Path $workDir "vivaldi-swift.zip"
    Info "Downloading latest release..."
    try {
        Invoke-WebRequest -Uri "$ReleaseBase/vivaldi-swift.zip" -OutFile $archive -UseBasicParsing
    } catch {
        Fail "Download failed. Check your connection and the `$Repo placeholder in this script."
    }

    $extractDir = Join-Path $workDir "extracted"
    try {
        Expand-Archive -Path $archive -DestinationPath $extractDir -Force
    } catch {
        Fail "Could not extract the downloaded release archive: $($_.Exception.Message)"
    }

    $versionFileMatch = Get-ChildItem -Path $extractDir -Recurse -Filter "version.json" -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $versionFileMatch) {
        Fail "Downloaded release archive has an unexpected layout."
    }
    $newRoot = $versionFileMatch.DirectoryName
    Ok "Downloaded and extracted v$remoteVersion"

    # --------------------------------------------------------------------
    # Replace only the files Vivaldi Swift owns. Icons, logs, backups, and
    # any local overrides (*.local.css/js) are never touched.
    # --------------------------------------------------------------------
    Info "Updating CSS, JS, and patch engine..."

    Copy-Item -Path (Join-Path $newRoot "css\vivaldi_swift.css") -Destination (Join-Path $ModDir "vivaldi_swift.css") -Force
    Copy-Item -Path (Join-Path $newRoot "js\custom.js") -Destination (Join-Path $ModDir "custom.js") -Force

    New-Item -ItemType Directory -Force -Path (Join-Path $ModDir "bin") | Out-Null
    Copy-Item -Path (Join-Path $newRoot "install\patch\patch-windows.ps1") -Destination (Join-Path $ModDir "bin\patch-windows.ps1") -Force

    $newUninstall = Join-Path $newRoot "install\uninstall-windows.ps1"
    if (Test-Path $newUninstall) {
        Copy-Item -Path $newUninstall -Destination (Join-Path $ModDir "bin\uninstall-windows.ps1") -Force
    }
    $newUpdate = Join-Path $newRoot "install\update-windows.ps1"
    if (Test-Path $newUpdate) {
        Copy-Item -Path $newUpdate -Destination (Join-Path $ModDir "bin\update-windows.ps1") -Force
    }
    $newVersion = Join-Path $newRoot "version.json"
    if (Test-Path $newVersion) {
        Copy-Item -Path $newVersion -Destination (Join-Path $ModDir "version.json") -Force
    }

    Ok "Files updated."

    # --------------------------------------------------------------------
    # Reapply the patch with the freshly-updated files
    # --------------------------------------------------------------------
    Info "Reapplying patch..."
    $patchScript = Join-Path $ModDir "bin\patch-windows.ps1"
    & $patchScript -ModDir $ModDir -Yes
    if ($LASTEXITCODE -ne 0) {
        Fail "Patch reapplication failed. See $ModDir\logs\patch-windows.log for details."
    }

    Write-Host ""
    Ok "Updated to v$remoteVersion. Restart Vivaldi to see the changes."
} finally {
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}
