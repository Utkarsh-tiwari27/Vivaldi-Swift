<#
.SYNOPSIS
    Vivaldi Swift — Bootstrap Installer (Windows)

.DESCRIPTION
    Lets a first-time user install Vivaldi Swift with a single command,
    without cloning the repository or downloading a ZIP by hand:

        irm https://raw.githubusercontent.com/vivaldi-swift/vivaldi-swift/main/install/bootstrap.ps1 | iex

    It downloads the latest GitHub Release, extracts it, runs
    install-windows.ps1, and cleans up after itself.

.PARAMETER Yes
    Passed through to install-windows.ps1: non-interactive mode.

.PARAMETER NoAutoPatch
    Passed through to install-windows.ps1: skip the auto-reapply task.
#>

[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$NoAutoPatch
)

$ErrorActionPreference = "Stop"

# Placeholder org/repo — matches the rest of the project until it's
# published under its real GitHub location.
$Repo = "vivaldi-swift/vivaldi-swift"
$ArchiveUrl = "https://github.com/$Repo/releases/latest/download/vivaldi-swift.zip"

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
    Info "Downloading the latest release..."
    try {
        Invoke-WebRequest -Uri $ArchiveUrl -OutFile $archive -UseBasicParsing
    } catch {
        Fail "Download failed. Check your connection and the `$Repo placeholder in this script."
    }
    Ok "Downloaded latest release"

    $extractDir = Join-Path $workDir "extracted"
    try {
        Expand-Archive -Path $archive -DestinationPath $extractDir -Force
    } catch {
        Fail "Could not extract the downloaded release archive: $($_.Exception.Message)"
    }

    $installerMatch = Get-ChildItem -Path $extractDir -Recurse -Filter "install-windows.ps1" -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $installerMatch) {
        Fail "Could not find install-windows.ps1 in the downloaded release. The release archive layout may have changed."
    }

    Write-Host "──────────────────────────────"
    $installerArgs = @{}
    if ($Yes) { $installerArgs["Yes"] = $true }
    if ($NoAutoPatch) { $installerArgs["NoAutoPatch"] = $true }

    & $installerMatch.FullName @installerArgs
} finally {
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}
