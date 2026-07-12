<#
.SYNOPSIS
    Vivaldi Swift — Shared PowerShell Library

.DESCRIPTION
    Dot-sourced by every Windows install, update, patch, and uninstall
    script. Centralizes terminal output, logging, and repository snapshot
    syncing so each platform script only contains what actually differs.

    Not meant to be run directly.
#>

$VivaldiSwiftRepo         = "Utkarsh-tiwari27/Vivaldi-Swift"
$VivaldiSwiftBranch       = "main"
$VivaldiSwiftCodeloadUrl  = "https://codeload.github.com/$VivaldiSwiftRepo/zip/refs/heads/$VivaldiSwiftBranch"
$VivaldiSwiftApiCommitUrl = "https://api.github.com/repos/$VivaldiSwiftRepo/commits/$VivaldiSwiftBranch"

# Render unicode checkmarks/arrows correctly on older Windows consoles;
# fall back silently (PowerShell keeps working either way).
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$Hr = "──────────────────────────────"

function Write-Banner { param($m) Write-Host $Hr; Write-Host " $m"; Write-Host $Hr }
function Step { param($m) Write-Host "  $m" }
function Ok   { param($m) Write-Host "✓ $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "! $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "✗ $m" -ForegroundColor Red; exit 1 }

# ----------------------------------------------------------------------------
# Structured logging. Callers set $LogFile and $Quiet before calling
# Write-Log; the log directory is created automatically.
# ----------------------------------------------------------------------------
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($LogFile) {
        New-Item -ItemType Directory -Force -Path (Split-Path $LogFile -Parent) | Out-Null
        "[$timestamp] [$Level] $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
    if (-not $Quiet) {
        switch ($Level) {
            "ERROR" { Write-Host "✗ $Message" -ForegroundColor Red }
            "WARN"  { Write-Host "! $Message" -ForegroundColor Yellow }
            "OK"    { Write-Host "✓ $Message" -ForegroundColor Green }
            default { Write-Host "  $Message" }
        }
    }
}

# ----------------------------------------------------------------------------
# Repository state — Vivaldi Swift has no version numbers or releases.
# "Changed" simply means "the latest commit on main has a different SHA
# than the one we last synced."
# ----------------------------------------------------------------------------
function Get-RemoteRepoSha {
    try {
        $response = Invoke-RestMethod -Uri $VivaldiSwiftApiCommitUrl -Headers @{ Accept = "application/vnd.github+json" }
        return $response.sha
    } catch {
        return $null
    }
}

function Get-LocalRepoSha {
    param([string]$StateFile)
    if (Test-Path $StateFile) {
        return (Get-Content -Path $StateFile -Raw).Trim()
    }
    return $null
}

# Downloads and extracts the current main-branch snapshot into $DestDir
# (created if needed). Returns the path to the extracted repository root.
function Get-RepoSnapshot {
    param([string]$DestDir)

    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
    $archive = Join-Path $DestDir "vivaldi-swift.zip"

    Invoke-WebRequest -Uri $VivaldiSwiftCodeloadUrl -OutFile $archive -UseBasicParsing

    $extractDir = Join-Path $DestDir "extracted"
    Expand-Archive -Path $archive -DestinationPath $extractDir -Force

    return (Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1).FullName
}
