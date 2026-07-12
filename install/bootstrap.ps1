<#
.SYNOPSIS
    Vivaldi Swift — Bootstrap Installer (Windows)

.DESCRIPTION
    Lets a first-time user install Vivaldi Swift with a single command,
    without cloning the repository by hand:

        irm https://raw.githubusercontent.com/Utkarsh-tiwari27/Vivaldi-Swift/main/install/bootstrap.ps1 | iex

    Vivaldi Swift has no releases or version numbers — the repository
    itself is the source of truth. This script downloads the current
    snapshot of the main branch, extracts it, runs install-windows.ps1,
    and cleans up after itself.

.PARAMETER Yes
    Passed through to install-windows.ps1: non-interactive mode.

.PARAMETER NoAutoPatch
    Passed through to install-windows.ps1: skip the auto-update task.
#>

[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$NoAutoPatch
)

$ErrorActionPreference = "Stop"

$Repo = "Utkarsh-tiwari27/Vivaldi-Swift"
$SnapshotUrl = "https://codeload.github.com/$Repo/zip/refs/heads/main"

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Info { param($m) Write-Host "  $m" }
function Ok   { param($m) Write-Host "✓ $m" -ForegroundColor Green }
function Fail { param($m) Write-Host "✗ $m" -ForegroundColor Red; exit 1 }

Write-Host "──────────────────────────────"
Write-Host " Vivaldi Swift Installer"
Write-Host "──────────────────────────────"
Ok "Detecting operating system"
Info "Windows"

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vivaldi-swift-bootstrap-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

try {
    $archive = Join-Path $workDir "vivaldi-swift.zip"
    Info "Downloading the latest repository snapshot..."
    try {
        Invoke-WebRequest -Uri $SnapshotUrl -OutFile $archive -UseBasicParsing
    } catch {
        Fail "Download failed. Check your connection and that $Repo exists and has a main branch."
    }
    Ok "Downloaded latest snapshot"

    $extractDir = Join-Path $workDir "extracted"
    try {
        Expand-Archive -Path $archive -DestinationPath $extractDir -Force
    } catch {
        Fail "Could not extract the downloaded snapshot archive: $($_.Exception.Message)"
    }

    $installerMatch = Get-ChildItem -Path $extractDir -Recurse -Filter "install-windows.ps1" -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $installerMatch) {
        Fail "Could not find install-windows.ps1 in the downloaded snapshot. The repository layout may have changed."
    }

    Write-Host "──────────────────────────────"
    $installerArgs = @{}
    if ($Yes) { $installerArgs["Yes"] = $true }
    if ($NoAutoPatch) { $installerArgs["NoAutoPatch"] = $true }

    & $installerMatch.FullName @installerArgs
} finally {
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}
