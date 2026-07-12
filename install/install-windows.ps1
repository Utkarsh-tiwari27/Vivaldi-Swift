<#
.SYNOPSIS
    Vivaldi Swift — Windows Installer

.DESCRIPTION
    Sets up %USERPROFILE%\Vivaldi-Swift, copies the CSS/JS payload and
    patch engine into it, applies the patch to a detected Vivaldi
    installation, and registers a Task Scheduler task that keeps Vivaldi
    Swift patched and quietly up to date on its own — no manual update
    command required.

.PARAMETER Yes
    Non-interactive mode (auto-confirm all prompts).

.PARAMETER NoAutoPatch
    Skip registering the Task Scheduler auto-update task.

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
. (Join-Path $ScriptDir "lib\common.ps1")

$ModDir   = "$env:USERPROFILE\Vivaldi-Swift"
$TaskName = "VivaldiSwiftAutoUpdate"

Write-Banner "Vivaldi Swift Installer"

# ------------------------------------------------------------------------
# 1. Detect operating system (informational)
# ------------------------------------------------------------------------
Ok "Detecting operating system"
Step ([System.Environment]::OSVersion.VersionString)

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
Step $FoundInstall

# ------------------------------------------------------------------------
# 3. Create the Vivaldi-Swift directory layout
# ------------------------------------------------------------------------
foreach ($sub in @("css", "js", "icons", "backups", "logs", "bin\lib")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $ModDir $sub) | Out-Null
}
Ok "Creating directories"
Step $ModDir

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

# ------------------------------------------------------------------------
# 5. Install the patch engine + auto-updater into $ModDir\bin, and record
#    which repository snapshot this install came from.
# ------------------------------------------------------------------------
Copy-Item -Path (Join-Path $ScriptDir "lib\common.ps1") -Destination (Join-Path $ModDir "bin\lib\common.ps1") -Force
Copy-Item -Path (Join-Path $ScriptDir "patch\patch-windows.ps1") -Destination (Join-Path $ModDir "bin\patch-windows.ps1") -Force
Copy-Item -Path (Join-Path $ScriptDir "update-windows.ps1") -Destination (Join-Path $ModDir "bin\update-windows.ps1") -Force
Copy-Item -Path (Join-Path $ScriptDir "uninstall-windows.ps1") -Destination (Join-Path $ModDir "bin\uninstall-windows.ps1") -Force

$PatchScript = Join-Path $ModDir "bin\patch-windows.ps1"

try {
    $sha = Get-RemoteRepoSha
    if ($sha) { Set-Content -Path (Join-Path $ModDir ".repo-sha") -Value $sha -NoNewline -Encoding utf8 }
} catch { }

# ------------------------------------------------------------------------
# 6. Register the background auto-update service. It reapplies the patch
#    and quietly syncs new repository changes on its own — there is no
#    manual update command.
# ------------------------------------------------------------------------
if (-not $NoAutoPatch) {
    try {
        # Remove any task registered by an older version of the installer.
        Unregister-ScheduledTask -TaskName "VivaldiSwiftPatch" -Confirm:$false -ErrorAction SilentlyContinue

        $updateScript = Join-Path $ModDir "bin\update-windows.ps1"
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$updateScript`" -Quiet"

        $triggerLogon = New-ScheduledTaskTrigger -AtLogOn
        $triggerDaily = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 24) -RepetitionDuration ([TimeSpan]::MaxValue)

        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        Register-ScheduledTask -TaskName $TaskName `
            -Action $action `
            -Trigger @($triggerLogon, $triggerDaily) `
            -Settings $settings `
            -Description "Keeps Vivaldi Swift patched and up to date. Runs daily; the script self-gates so logon runs are cheap." `
            -Force | Out-Null

        Ok "Installing auto-update service"
        Step "Task Scheduler task '$TaskName' (runs daily and at logon)"
    } catch {
        Ok "Installing auto-update service"
        Warn "Could not register the scheduled task automatically: $($_.Exception.Message)"
        Warn "You can create it manually via Task Scheduler, running: powershell.exe -File `"$updateScript`" -Quiet"
    }
} else {
    Ok "Installing auto-update service"
    Step "auto-update skipped (-NoAutoPatch)"
}

# ------------------------------------------------------------------------
# 7. Apply the patch (backs up window.html, injects CSS/JS, then verifies —
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
Write-Host "Vivaldi Swift updates itself automatically — nothing else to run."
Write-Host "To uninstall, run: install\uninstall-windows.ps1"
