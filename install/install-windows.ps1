<#
.SYNOPSIS
    Vivaldi Swift — Windows Installer

.DESCRIPTION
    Sets up %USERPROFILE%\Vivaldi-Swift, copies the CSS/JS payload and
    patch engine into it, applies the patch to a detected Vivaldi
    installation, and registers a Task Scheduler task that keeps the mod
    re-applied after Vivaldi auto-updates.

.PARAMETER Yes
    Non-interactive mode (auto-confirm all prompts).

.PARAMETER NoAutoPatch
    Skip registering the Task Scheduler auto-reapply task.

.EXAMPLE
    .\install-windows.ps1

.EXAMPLE
    .\install-windows.ps1 -Yes -NoAutoPatch
#>

[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$NoAutoPatch
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$ModDir    = "$env:USERPROFILE\Vivaldi-Swift"
$TaskName  = "VivaldiSwiftPatch"

# Try to render unicode checkmarks/arrows correctly on older Windows
# consoles; fall back silently (PowerShell keeps working either way).
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

function Info { param($m) Write-Host "  $m" }
function Ok   { param($m) Write-Host "✓ $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "! $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "✗ $m" -ForegroundColor Red; exit 1 }

$Hr = "──────────────────────────────"

Write-Host $Hr
Write-Host " Vivaldi Swift Installer"
Write-Host $Hr

# ------------------------------------------------------------------------
# 1. Detect operating system (informational)
# ------------------------------------------------------------------------
Ok "Detecting operating system"
Info ([System.Environment]::OSVersion.VersionString)

# ------------------------------------------------------------------------
# 2. Detect Vivaldi
# ------------------------------------------------------------------------
$Roots = @(
    "$env:ProgramFiles\Vivaldi",
    "${env:ProgramFiles(x86)}\Vivaldi",
    "$env:LocalAppData\Vivaldi"
)

$FoundInstall = $null
foreach ($root in $Roots) {
    if (-not (Test-Path $root)) { continue }
    $appRoot = Join-Path $root "Application"
    if (-not (Test-Path $appRoot)) { continue }

    $versionDirs = Get-ChildItem -Path $appRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending

    foreach ($v in $versionDirs) {
        $candidate = Join-Path $v.FullName "resources\vivaldi\window.html"
        if (Test-Path $candidate) {
            $FoundInstall = $root
            break
        }
    }
    if ($FoundInstall) { break }
}

if (-not $FoundInstall) {
    Fail "Vivaldi was not found under Program Files, Program Files (x86), or LocalAppData. Install Vivaldi first: https://vivaldi.com/download/"
}
Ok "Detecting Vivaldi installation"
Info $FoundInstall

# ------------------------------------------------------------------------
# 3. Create the Vivaldi-Swift directory layout
# ------------------------------------------------------------------------
foreach ($sub in @("css", "js", "icons", "backups", "logs", "bin")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $ModDir $sub) | Out-Null
}
Ok "Creating directories"
Info $ModDir

# ------------------------------------------------------------------------
# 4. Copy payload files
# ------------------------------------------------------------------------
Copy-Item -Path (Join-Path $RepoRoot "css\vivaldi_swift.css") -Destination (Join-Path $ModDir "vivaldi_swift.css") -Force
Ok "Installing CSS"

Copy-Item -Path (Join-Path $RepoRoot "js\custom.js") -Destination (Join-Path $ModDir "custom.js") -Force
Ok "Installing JavaScript"

$IconsSrc = Join-Path $RepoRoot "icons"
if (Test-Path $IconsSrc) {
    Copy-Item -Path "$IconsSrc\*" -Destination (Join-Path $ModDir "icons") -Recurse -Force -ErrorAction SilentlyContinue
}
$VersionSrc = Join-Path $RepoRoot "version.json"
if (Test-Path $VersionSrc) {
    Copy-Item -Path $VersionSrc -Destination (Join-Path $ModDir "version.json") -Force
}

# ------------------------------------------------------------------------
# 5. Install the patch service: copy the patch engine into $ModDir\bin and
#    register the background task that keeps it reapplied after Vivaldi
#    updates (Task Scheduler).
# ------------------------------------------------------------------------
Copy-Item -Path (Join-Path $ScriptDir "patch\patch-windows.ps1") -Destination (Join-Path $ModDir "bin\patch-windows.ps1") -Force
$UninstallSrc = Join-Path $ScriptDir "uninstall-windows.ps1"
if (Test-Path $UninstallSrc) {
    Copy-Item -Path $UninstallSrc -Destination (Join-Path $ModDir "bin\uninstall-windows.ps1") -Force
}
$UpdateSrc = Join-Path $ScriptDir "update-windows.ps1"
if (Test-Path $UpdateSrc) {
    Copy-Item -Path $UpdateSrc -Destination (Join-Path $ModDir "bin\update-windows.ps1") -Force
}

$PatchScript = Join-Path $ModDir "bin\patch-windows.ps1"

if (-not $NoAutoPatch) {
    try {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PatchScript`" -ModDir `"$ModDir`" -Yes -Quiet"

        $triggerLogon = New-ScheduledTaskTrigger -AtLogOn
        $triggerDaily = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 6) -RepetitionDuration ([TimeSpan]::MaxValue)

        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        Register-ScheduledTask -TaskName $TaskName `
            -Action $action `
            -Trigger @($triggerLogon, $triggerDaily) `
            -Settings $settings `
            -Description "Reapplies the Vivaldi Swift UI patch after Vivaldi updates." `
            -Force | Out-Null

        Ok "Installing patch service"
        Info "Task Scheduler task '$TaskName' (runs at logon and every 6h)"
    } catch {
        Ok "Installing patch service"
        Warn "Could not register the scheduled task automatically: $($_.Exception.Message)"
        Warn "You can create it manually via Task Scheduler, running: powershell.exe -File `"$PatchScript`" -Yes -Quiet"
    }
} else {
    Ok "Installing patch service"
    Info "auto-reapply skipped (-NoAutoPatch)"
}

# ------------------------------------------------------------------------
# 6. Apply the patch (backs up window.html, injects CSS/JS, then verifies —
#    automatically rolling back if verification fails)
# ------------------------------------------------------------------------
$PatchArgs = @{ ModDir = $ModDir }
if ($Yes) { $PatchArgs["Yes"] = $true }

& $PatchScript @PatchArgs
if ($LASTEXITCODE -ne 0) {
    Fail "Patch failed. See $ModDir\logs\patch-windows.log for details."
}

# ------------------------------------------------------------------------
# Done
# ------------------------------------------------------------------------
Ok "Done"
Write-Host $Hr
Write-Host ""
Write-Host "Final Step"
Write-Host $Hr
Write-Host ""
Write-Host "  Open Vivaldi and go to:"
Write-Host ""
Write-Host "    Settings"
Write-Host "      ↓"
Write-Host "    Appearance"
Write-Host "      ↓"
Write-Host "    Custom UI Modifications"
Write-Host "      ↓"
Write-Host "    Select: $ModDir"
Write-Host "      ↓"
Write-Host "    Restart Vivaldi"
Write-Host ""
Write-Host $Hr
Write-Host ""
Write-Host "  Logs    : $ModDir\logs\"
Write-Host "  Backups : $ModDir\backups\"
Write-Host ""
Write-Host "To uninstall, run: install\uninstall-windows.ps1"
