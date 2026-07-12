<#
.SYNOPSIS
    Vivaldi Swift — Windows Patch Engine

.DESCRIPTION
    Injects the Vivaldi Swift CSS and JS into a Vivaldi installation's
    window.html so the modifications load on every browser start.

    Detects:
      - Program Files\Vivaldi                  (per-machine install)
      - Program Files (x86)\Vivaldi            (32-bit install path)
      - %LocalAppData%\Vivaldi                 (per-user install, default)
      - Portable installs via -InstallDir

    Always backs up window.html to Vivaldi-Swift\backups\windows before
    modifying it, and is idempotent: re-running the script will not
    duplicate the injected <link>/<script> tags.

.PARAMETER ModDir
    Directory containing vivaldi_swift.css and custom.js.
    Defaults to "$env:USERPROFILE\Vivaldi-Swift".

.PARAMETER InstallDir
    Explicit path to a Vivaldi "Application\<version>\resources\vivaldi"
    style directory (or an application root containing it). Skips
    auto-detection.

.PARAMETER Yes
    Non-interactive mode: auto-selects when exactly one installation is
    found, fails otherwise.

.PARAMETER Quiet
    Suppress console output (log file is still written).

.EXAMPLE
    .\patch-windows.ps1

.EXAMPLE
    .\patch-windows.ps1 -InstallDir "D:\PortableApps\Vivaldi" -Yes
#>

[CmdletBinding()]
param(
    [string]$ModDir = "$env:USERPROFILE\Vivaldi-Swift",
    [string]$InstallDir = "",
    [switch]$Yes,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# Try to render unicode checkmarks correctly on older Windows consoles;
# fall back silently (PowerShell keeps working either way).
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$CssFile   = "vivaldi_swift.css"
$JsFile    = "custom.js"
$CssMarker = '<link rel="stylesheet" href="vivaldi_swift.css">'
$JsMarker  = '<script src="custom.js"></script>'

$LogDir  = Join-Path $ModDir "logs"
$LogFile = Join-Path $LogDir "patch-windows.log"

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    "[$timestamp] [$Level] $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8

    if (-not $Quiet) {
        switch ($Level) {
            "ERROR" { Write-Host "✗ $Message" -ForegroundColor Red }
            "WARN"  { Write-Host "! $Message" -ForegroundColor Yellow }
            "OK"    { Write-Host "✓ $Message" -ForegroundColor Green }
            default { Write-Host "  $Message" }
        }
    }
}

function Exit-WithCode {
    param([int]$Code, [string]$Message)
    if ($Message) { Write-Log "ERROR" $Message }
    Write-Log "INFO" "=== patch-windows.ps1 finished (exit $Code) ==="
    exit $Code
}

Write-Log "INFO" "=== patch-windows.ps1 started (mod-dir=$ModDir) ==="

# ------------------------------------------------------------------------
# Locate candidate Vivaldi installations
# ------------------------------------------------------------------------
function Find-VivaldiInstalls {
    $roots = @(
        "$env:ProgramFiles\Vivaldi",
        "${env:ProgramFiles(x86)}\Vivaldi",
        "$env:LocalAppData\Vivaldi"
    )

    $found = @()
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }

        $appRoot = Join-Path $root "Application"
        if (-not (Test-Path $appRoot)) { continue }

        # Versioned subfolders, e.g. Application\6.7.3329.41\resources\vivaldi
        Get-ChildItem -Path $appRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object {
                $candidate = Join-Path $_.FullName "resources\vivaldi\window.html"
                if (Test-Path $candidate) {
                    $found += (Join-Path $_.FullName "resources\vivaldi")
                }
            }
    }

    return $found | Select-Object -Unique
}

if ($InstallDir -ne "") {
    if (Test-Path (Join-Path $InstallDir "window.html")) {
        $vivaldiDir = $InstallDir
    } else {
        $nested = Join-Path $InstallDir "resources\vivaldi"
        if (Test-Path (Join-Path $nested "window.html")) {
            $vivaldiDir = $nested
        } else {
            Exit-WithCode 1 "No window.html found under -InstallDir '$InstallDir'."
        }
    }
} else {
    $candidates = Find-VivaldiInstalls

    if ($candidates.Count -eq 0) {
        Exit-WithCode 1 "No Vivaldi installation found under Program Files, Program Files (x86), or LocalAppData."
    } elseif ($candidates.Count -eq 1) {
        $vivaldiDir = $candidates[0]
        Write-Log "INFO" "Single Vivaldi installation detected: $vivaldiDir"
    } elseif ($Yes) {
        Exit-WithCode 1 "Multiple installations found and -Yes was given; specify -InstallDir explicitly. Candidates: $($candidates -join ', ')"
    } else {
        Write-Host "---------------------"
        Write-Host "Vivaldi installations found:"
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host "$($i + 1)) $($candidates[$i])"
        }
        Write-Host ""
        $answer = Read-Host "Select installation number (X to cancel)"

        if ($answer -eq "X" -or $answer -eq "x") {
            Write-Log "INFO" "User cancelled selection."
            exit 0
        }

        $index = 0
        if (-not [int]::TryParse($answer, [ref]$index)) {
            Exit-WithCode 1 "Invalid selection: $answer"
        }
        $index = $index - 1
        if ($index -lt 0 -or $index -ge $candidates.Count) {
            Exit-WithCode 1 "Selection out of range: $answer"
        }

        $vivaldiDir = $candidates[$index]
    }
}

Write-Log "INFO" "Mod directory : $ModDir"
Write-Log "INFO" "Target        : $vivaldiDir"

# ------------------------------------------------------------------------
# Verify required files
# ------------------------------------------------------------------------
$windowHtml = Join-Path $vivaldiDir "window.html"
if (-not (Test-Path $windowHtml)) {
    Exit-WithCode 1 "window.html not found at $vivaldiDir"
}

$modCss = Join-Path $ModDir $CssFile
$modJs  = Join-Path $ModDir $JsFile

if (-not (Test-Path $modJs)) {
    Exit-WithCode 2 "custom.js missing: $modJs (run the installer first)"
}
if (-not (Test-Path $modCss)) {
    Exit-WithCode 2 "vivaldi_swift.css missing: $modCss (run the installer first)"
}

# ------------------------------------------------------------------------
# Detect Vivaldi version for logging
# ------------------------------------------------------------------------
$vivaldiVersion = "unknown"
try {
    $exe = Get-ChildItem -Path (Split-Path $vivaldiDir -Parent) -Filter "vivaldi.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($exe) {
        $vivaldiVersion = $exe.VersionInfo.ProductVersion
    }
} catch {
    $vivaldiVersion = "unknown"
}
Write-Log "INFO" "Detected Vivaldi version: $vivaldiVersion"

# ------------------------------------------------------------------------
# Permission check
# ------------------------------------------------------------------------
try {
    $testFile = Join-Path $vivaldiDir ".vivaldi-swift-write-test"
    [System.IO.File]::WriteAllText($testFile, "test")
    Remove-Item $testFile -Force
} catch {
    Exit-WithCode 3 "No write permission to $vivaldiDir. Try running this script as Administrator."
}

# ------------------------------------------------------------------------
# Restore window.html from a backup and explain what happened. Used
# whenever post-patch verification fails, so a bad patch never sticks
# around.
# ------------------------------------------------------------------------
function Restore-Backup {
    param([string]$Reason)

    Write-Log "ERROR" "Verification failed: $Reason"

    $restoreFrom = $script:BackupPath
    if (-not $restoreFrom) {
        $backupDir = Join-Path $ModDir "backups\windows"
        $latest = Get-ChildItem -Path $backupDir -Filter "window.html-*" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($latest) { $restoreFrom = $latest.FullName }
    }

    if ($restoreFrom -and (Test-Path $restoreFrom)) {
        try {
            Copy-Item -Path $restoreFrom -Destination $windowHtml -Force
            Write-Log "OK" "Backup restored from $restoreFrom - Vivaldi is back to its previous state."
        } catch {
            Write-Log "ERROR" "Automatic restore also failed: $($_.Exception.Message)"
            Write-Log "ERROR" "Manually restore with: Copy-Item '$restoreFrom' '$windowHtml' -Force"
        }
    } else {
        Write-Log "ERROR" "No backup was available to restore. Please reinstall Vivaldi or restore window.html manually."
    }

    Exit-WithCode 4 "Vivaldi Swift was not applied. See $LogFile for details."
}

# ------------------------------------------------------------------------
# Idempotency check
# ------------------------------------------------------------------------
$currentContent = Get-Content -Path $windowHtml -Raw
$alreadyPatched = $currentContent.Contains($JsMarker) -and $currentContent.Contains($CssMarker)

$script:BackupPath = $null

if ($alreadyPatched) {
    Write-Log "OK" "window.html already patched. Refreshing asset copies only."
} else {
    $backupDir = Join-Path $ModDir "backups\windows"
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH-mm-ss"
    $backupPath = Join-Path $backupDir "window.html-$timestamp"

    Write-Log "INFO" "Creating backup at $backupPath"
    try {
        Copy-Item -Path $windowHtml -Destination $backupPath -Force
    } catch {
        Exit-WithCode 4 "Failed to create backup: $($_.Exception.Message)"
    }
    if (-not (Test-Path $backupPath) -or (Get-Item $backupPath).Length -eq 0) {
        Exit-WithCode 4 "Backup at $backupPath is missing or empty. Aborting before touching window.html."
    }
    $script:BackupPath = $backupPath
    Write-Log "OK" "Creating backup"

    Write-Log "INFO" "Injecting CSS and JS references into window.html"

    $newContent = $currentContent
    if (-not $newContent.Contains($CssMarker)) {
        $newContent = $newContent -replace "</body>", "$CssMarker</body>"
    }
    if (-not $newContent.Contains($JsMarker)) {
        $newContent = $newContent -replace "</body>", "$JsMarker</body>"
    }

    try {
        Set-Content -Path $windowHtml -Value $newContent -NoNewline -Encoding utf8
    } catch {
        Restore-Backup "could not write patched window.html ($($_.Exception.Message))"
    }

    Write-Log "OK" "window.html patched successfully."
}

# ------------------------------------------------------------------------
# Copy CSS + JS payloads into the Vivaldi resource directory
# ------------------------------------------------------------------------
Write-Log "INFO" "Copying $CssFile and $JsFile into $vivaldiDir"

try {
    Copy-Item -Path $modCss -Destination (Join-Path $vivaldiDir $CssFile) -Force
    Copy-Item -Path $modJs  -Destination (Join-Path $vivaldiDir $JsFile) -Force
} catch {
    Restore-Backup "could not copy mod files into place ($($_.Exception.Message))"
}

# ------------------------------------------------------------------------
# Verify the patch actually took before declaring success. This is what
# lets the installer's "Verifying installation" step mean something.
# ------------------------------------------------------------------------
Write-Log "INFO" "Verifying CSS and JS were successfully injected"

$patchedContent = Get-Content -Path $windowHtml -Raw
if (-not $patchedContent.Contains($CssMarker)) {
    Restore-Backup "CSS reference is missing from window.html"
}
if (-not $patchedContent.Contains($JsMarker)) {
    Restore-Backup "JS reference is missing from window.html"
}

$installedCss = Join-Path $vivaldiDir $CssFile
$installedJs  = Join-Path $vivaldiDir $JsFile
if (-not (Test-Path $installedCss) -or (Get-Item $installedCss).Length -eq 0) {
    Restore-Backup "$CssFile is missing or empty at $vivaldiDir"
}
if (-not (Test-Path $installedJs) -or (Get-Item $installedJs).Length -eq 0) {
    Restore-Backup "$JsFile is missing or empty at $vivaldiDir"
}

Write-Log "OK" "Verifying installation"

$vivaldiVersion | Out-File -FilePath (Join-Path $LogDir ".last-patched-version") -Encoding utf8 -NoNewline

Write-Log "OK" "Vivaldi Swift patch applied (Vivaldi $vivaldiVersion)."
Write-Log "INFO" "=== patch-windows.ps1 finished ==="
exit 0
