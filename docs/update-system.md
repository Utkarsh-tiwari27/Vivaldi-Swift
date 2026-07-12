# Update System

Vivaldi periodically auto-updates in the background, and every update
overwrites `window.html` — which silently removes the `<link>`/`<script>`
tags Vivaldi Swift depends on. This document explains how Vivaldi Swift
detects and recovers from that automatically.

## The problem, concretely

1. Vivaldi Swift patches `resources/vivaldi/window.html` to load
   `vivaldi_swift.css` and `custom.js`.
2. Vivaldi ships a new version. Its updater replaces the entire
   `resources/vivaldi/` directory (or installs a new versioned directory, on
   Windows) with a clean copy from the update package.
3. The injected tags — and the copied `vivaldi_swift.css`/`custom.js` files
   — are gone. Vivaldi Swift's UI changes disappear on next launch.

## The fix: scheduled reapplication

Each installer registers a lightweight, platform-native background job that
re-runs the patch engine on a schedule and at login:

| Platform | Mechanism | Schedule |
|---|---|---|
| Linux | `systemd --user` timer (`vivaldi-swift.timer`), cron fallback | Every 6 hours + at login/boot |
| macOS | `LaunchAgent` (`com.vivaldiswift.patch`) | Every 6 hours + at login |
| Windows | Task Scheduler task (`VivaldiSwiftPatch`) | Every 6 hours + at logon |

The patch engine itself is **idempotent**: it checks whether the injection
markers are already present before doing anything, so running it when
nothing changed is a cheap no-op — no duplicate tags, no unnecessary
backups.

```
patch engine run
  ├─ window.html has both markers already?
  │     yes → refresh copied CSS/JS only, verify, exit
  │     no  → verify a backup can be created (timestamped)
  │           inject <link>/<script> markers
  │           copy current CSS/JS into place
  │           verify both markers and both files are actually present
  │             ├─ pass → done
  │             └─ fail → restore window.html from the backup, exit non-zero
  └─ log outcome (timestamp, Vivaldi version, status) to logs/
```

## Post-patch verification & automatic rollback

Every patch run ends with a verification pass: it re-reads `window.html` to
confirm both the `<link>` and `<script>` markers are present, and confirms
`vivaldi_swift.css`/`custom.js` were actually copied into Vivaldi's resource
directory and aren't empty. If any of those checks fail — for example, a
disk write error or an unexpected `window.html` layout — the patch engine
automatically restores the backup it took before making any changes, so
Vivaldi is never left in a half-patched state. The failure is logged with a
specific reason and the script exits non-zero; it never fails silently.

## Detecting whether a patch is required

The "already patched" check is a simple, fast text search for both injection
markers in `window.html`:

```
<link rel="stylesheet" href="vivaldi_swift.css">
<script src="custom.js"></script>
```

If Vivaldi's updater replaced the file, neither marker is present, so the
next scheduled run detects this and re-patches within the schedule window
(up to 6 hours, or immediately at the next login — whichever comes first).

## Manual reapplication

You don't need to wait for the schedule. Run the patch engine directly:

```bash
# Linux
~/Vivaldi-Swift/bin/patch-linux.sh

# macOS
~/Vivaldi-Swift/bin/patch-macos.sh
```

```powershell
# Windows
& "$env:USERPROFILE\Vivaldi-Swift\bin\patch-windows.ps1"
```

Each accepts `--yes`/`-Yes` for non-interactive mode and `--quiet`/`-Quiet`
to suppress console output (used by the scheduled task itself).

## Logs

Every run appends a structured entry to the platform's log file:

- Linux: `~/Vivaldi-Swift/logs/patch-linux.log`
- macOS: `~/Vivaldi-Swift/logs/patch-macos.log`
- Windows: `%USERPROFILE%\Vivaldi-Swift\logs\patch-windows.log`

Each line records a timestamp, a level (`INFO`/`OK`/`WARN`/`ERROR`), and the
event — including the detected Vivaldi version, backup paths, and any
failure reason. The most recently patched Vivaldi version is also written to
a small marker file (`logs/.last-patched-version`) for quick inspection.

## Checking the background task status

**Linux (systemd):**
```bash
systemctl --user status vivaldi-swift.timer
systemctl --user list-timers vivaldi-swift.timer
```

**Linux (cron fallback):**
```bash
crontab -l | grep patch-linux.sh
```

**macOS:**
```bash
launchctl list | grep com.vivaldiswift.patch
```

**Windows:**
```powershell
Get-ScheduledTask -TaskName VivaldiSwiftPatch | Get-ScheduledTaskInfo
```

## Disabling automatic reapplication

If you'd rather patch manually after each Vivaldi update:

- Pass `--no-auto-patch` (`-NoAutoPatch` on Windows) to the installer.
- Or remove the task after the fact — see the relevant uninstall script, or
  disable it directly:
  ```bash
  systemctl --user disable --now vivaldi-swift.timer   # Linux
  launchctl unload ~/Library/LaunchAgents/com.vivaldiswift.patch.plist  # macOS
  ```
  ```powershell
  Unregister-ScheduledTask -TaskName VivaldiSwiftPatch  # Windows
  ```

## Self-updater

The background task above only re-applies the *current* CSS/JS/patch engine
after Vivaldi overwrites `window.html` — it doesn't fetch new Vivaldi Swift
releases. For that, run the updater for your platform:

```bash
~/Vivaldi-Swift/bin/update-linux.sh     # or update-macos.sh
```

```powershell
& "$env:USERPROFILE\Vivaldi-Swift\bin\update-windows.ps1"
```

(The source copies live at `install/update-linux.sh`, `install/update-macos.sh`,
and `install/update-windows.ps1`; the installer copies them into
`Vivaldi-Swift/bin/` alongside the patch engine so they're always available
without re-cloning the repository.)

What it does:

1. Downloads `version.json` from the latest GitHub Release and compares its
   `version` field against `Vivaldi-Swift/version.json`. If they match, it
   prints "Already up to date" and exits — no further download happens.
2. Otherwise, downloads and extracts the full release archive.
3. Replaces `vivaldi_swift.css`, `custom.js`, the patch/uninstall/update
   scripts, and `version.json`.
4. Reapplies the patch (with the same backup-and-verify safety described
   above).

It never touches `icons/`, `logs/`, `backups/`, or any local
`.local.css`/`.local.js` override — only the files Vivaldi Swift itself
owns are replaced, so custom icons and settings survive every update.

`version.json` (at the repository root, and copied into `Vivaldi-Swift/` on
install) is what makes step 1 cheap:

```json
{
    "version": "1.0.0",
    "minimum_vivaldi": "6.0",
    "patch_version": "1"
}
```
