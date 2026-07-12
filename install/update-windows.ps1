<#
.SYNOPSIS
    Vivaldi Swift — Windows Auto-Updater

.DESCRIPTION
    This is the background service the installer registers with Task
    Scheduler. It is not meant to be run manually — install once, forget
    it exists. Whenever the repository changes, Vivaldi Swift quietly
    updates itself; there is no manual update command to run.

    The repository itself is the source of truth: no version numbers, no
    releases. "An update is available" simply means "the latest commit on
    main has a different SHA than the one we last synced."

    To keep this genuinely lightweight:
      - A run started less than 24h after the last successful check exits
        immediately without touching the network at all (self-gating;
        this is what makes it safe to also trigger this script at logon).
      - If the repo hasn't changed, no snapshot is downloaded.
      - The patch is re-verified locally on every run (free, no network)
        so Vivaldi self-updates keep getting the UI reapplied even on
        days the repository itself doesn't change.

.PARAMETER Force
    Bypass the 24h staleness gate and check now.

.PARAMETER Quiet
    Suppress console output (log file still written).

.PARAMETER InstallDir
    Explicit Vivaldi install directory, passed through to the patch
    engine when reapplying.

.EXAMPLE
    .\update-windows.ps1

.EXAMPLE
    .\update-windows.ps1 -Force
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Quiet,
    [string]$InstallDir = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "lib\common.ps1")

$ModDir = "$env:USERPROFILE\Vivaldi-Swift"
$CheckIntervalSecs = 24 * 60 * 60

$LogFile       = Join-Path $ModDir "logs\update-windows.log"
$StateFile     = Join-Path $ModDir ".repo-sha"
$LastCheckFile = Join-Path $ModDir "logs\.last-update-check"

Write-Log "INFO" "=== update-windows.ps1 started ==="

if (-not (Test-Path $ModDir)) {
    Write-Log "ERROR" "Vivaldi Swift is not installed ($ModDir not found)."
    exit 1
}

# ------------------------------------------------------------------------
# Staleness gate — avoids unnecessary network traffic when triggered both
# on a daily task and at logon.
# ------------------------------------------------------------------------
if (-not $Force -and (Test-Path $LastCheckFile)) {
    $lastCheck = 0
    [int64]::TryParse((Get-Content $LastCheckFile -Raw).Trim(), [ref]$lastCheck) | Out-Null
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($lastCheck -gt 0 -and ($now - $lastCheck) -lt $CheckIntervalSecs) {
        Write-Log "INFO" "Checked recently; skipping until the next scheduled run."
        exit 0
    }
}

# ------------------------------------------------------------------------
# Compare the local and remote commit SHAs.
# ------------------------------------------------------------------------
$remoteSha = Get-RemoteRepoSha
if (-not $remoteSha) {
    Write-Log "WARN" "Could not reach GitHub to check for updates. Will retry on the next run."
    exit 0
}
[DateTimeOffset]::UtcNow.ToUnixTimeSeconds() | Out-File -FilePath $LastCheckFile -Encoding utf8 -NoNewline

$localSha = Get-LocalRepoSha -StateFile $StateFile

if ($remoteSha -eq $localSha) {
    Write-Log "OK" "Vivaldi Swift is up to date."
} else {
    Write-Log "INFO" "Repository has changed; syncing latest snapshot..."

    $workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vivaldi-swift-update-" + [System.Guid]::NewGuid().ToString("N"))
    try {
        $newRoot = $null
        try {
            $newRoot = Get-RepoSnapshot -DestDir $workDir
        } catch {
            Write-Log "ERROR" "Download or extraction failed: $($_.Exception.Message)"
            exit 2
        }
        if (-not $newRoot -or -not (Test-Path $newRoot)) {
            Write-Log "ERROR" "Downloaded snapshot has an unexpected layout."
            exit 2
        }

        Copy-Item -Path (Join-Path $newRoot "css\vivaldi_swift.css") -Destination (Join-Path $ModDir "vivaldi_swift.css") -Force
        Copy-Item -Path (Join-Path $newRoot "js\custom.js") -Destination (Join-Path $ModDir "custom.js") -Force

        New-Item -ItemType Directory -Force -Path (Join-Path $ModDir "bin\lib") | Out-Null
        Copy-Item -Path (Join-Path $newRoot "install\lib\common.ps1") -Destination (Join-Path $ModDir "bin\lib\common.ps1") -Force
        Copy-Item -Path (Join-Path $newRoot "install\patch\patch-windows.ps1") -Destination (Join-Path $ModDir "bin\patch-windows.ps1") -Force
        Copy-Item -Path (Join-Path $newRoot "install\update-windows.ps1") -Destination (Join-Path $ModDir "bin\update-windows.ps1") -Force
        Copy-Item -Path (Join-Path $newRoot "install\uninstall-windows.ps1") -Destination (Join-Path $ModDir "bin\uninstall-windows.ps1") -Force

        Set-Content -Path $StateFile -Value $remoteSha -NoNewline -Encoding utf8
        Write-Log "OK" "Repository synced to $remoteSha."
    } finally {
        Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------------------
# Reapply the patch unconditionally. Cheap, local, idempotent no-op if
# already patched — this is what keeps the UI intact after Vivaldi itself
# auto-updates.
# ------------------------------------------------------------------------
$PatchScript = Join-Path $ModDir "bin\patch-windows.ps1"
$PatchArgs = @{ ModDir = $ModDir; Yes = $true }
if ($Quiet) { $PatchArgs["Quiet"] = $true }
if ($InstallDir -ne "") { $PatchArgs["InstallDir"] = $InstallDir }

& $PatchScript @PatchArgs
if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR" "Patch reapplication failed. See $ModDir\logs\patch-windows.log for details."
    exit 3
}

Write-Log "INFO" "=== update-windows.ps1 finished ==="
