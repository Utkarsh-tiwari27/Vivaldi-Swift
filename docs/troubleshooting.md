# Troubleshooting

Common installation and patching problems, organized by symptom. If nothing
here resolves it, open an issue using the **Bug report** template and
attach the relevant log file — see
[CONTRIBUTING.md](../CONTRIBUTING.md#reporting-bugs).

---

## "No Vivaldi installation found"

**Linux:** The installer looks under `/opt` (for `vivaldi-bin` /
`vivaldi-snapshot-bin`) and `/snap/vivaldi`. If you installed Vivaldi to a
non-standard location, run the patch engine with an explicit path:

```bash
~/Vivaldi-Swift/bin/patch-linux.sh --install-dir "/path/to/resources/vivaldi"
```

**macOS:** Checked locations are `/Applications/Vivaldi.app`,
`~/Applications/Vivaldi.app`, and the Homebrew Caskroom. For any other
location:

```bash
~/Vivaldi-Swift/bin/patch-macos.sh --app-path "/path/to/Vivaldi.app"
```

**Windows:** Checked locations are `Program Files\Vivaldi`,
`Program Files (x86)\Vivaldi`, and `%LocalAppData%\Vivaldi`. For a portable
install:

```powershell
& "$env:USERPROFILE\Vivaldi-Swift\bin\patch-windows.ps1" -InstallDir "D:\PortableApps\Vivaldi"
```

---

## "Permission denied" / installer asks for sudo / fails writing files

Vivaldi installed under a system directory (`/opt`, `Program Files`,
`/Applications` in some configurations) requires elevated permissions to
modify. This is expected — the scripts request `sudo` (Linux/macOS) or
should be run from an **Administrator** PowerShell session (Windows) for
that specific step only. If you'd rather avoid elevated permissions
entirely, install Vivaldi to a per-user location (`~/Applications` on
macOS, or the default per-user installer on Windows, which installs to
`%LocalAppData%\Vivaldi` without needing admin rights).

---

## Nothing changed after installing / patching

1. **Fully quit Vivaldi** (not just close the window) and relaunch — the UI
   HTML is only re-read on startup.
2. Confirm the patch actually applied by checking the log file for `OK`
   status:
   - Linux: `~/Vivaldi-Swift/logs/patch-linux.log`
   - macOS: `~/Vivaldi-Swift/logs/patch-macos.log`
   - Windows: `%USERPROFILE%\Vivaldi-Swift\logs\patch-windows.log`
3. Confirm the markers are actually present in `window.html`:
   ```bash
   grep -F 'vivaldi_swift.css' "<vivaldi_dir>/window.html"
   grep -F 'custom.js' "<vivaldi_dir>/window.html"
   ```
4. If a very recent Vivaldi update just landed, the background reapply task
   may not have run yet — trigger it manually (see
   [update-system.md](update-system.md#manual-reapplication)).

---

## macOS: "Vivaldi.app is damaged and can't be opened"

This happens when macOS's Gatekeeper re-validates the code signature after
`window.html` was modified. The installer/patch script attempts an ad-hoc
re-sign automatically; if you still see this warning:

```bash
xattr -cr "/Applications/Vivaldi.app"
```

If that doesn't resolve it, re-run the patch script — the re-sign step logs
a `WARN` if it fails, which is visible in
`~/Vivaldi-Swift/logs/patch-macos.log`.

---

## Windows: "running scripts is disabled on this system"

PowerShell's default execution policy blocks unsigned scripts. Allow it for
the current session only (safer than changing the policy permanently):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then re-run the installer/patch script in the same PowerShell session.

---

## The patch keeps disappearing every time Vivaldi updates

This is expected behavior without the background reapply task — see
[update-system.md](update-system.md) for why Vivaldi updates remove the
patch, and confirm the scheduled task is actually registered:

```bash
systemctl --user list-timers vivaldi-swift.timer   # Linux
launchctl list | grep com.vivaldiswift.patch         # macOS
```
```powershell
Get-ScheduledTask -TaskName VivaldiSwiftPatch        # Windows
```

If it's missing, re-run the installer without `--no-auto-patch` /
`-NoAutoPatch`.

---

## Custom Speed Dial icons look wrong / misaligned after an update

Usually means the CSS loaded but a stale cached layout persisted. Try:

1. Right-click the affected tile → **Reset Layout** (keeps the icon, resets
   size/offset/padding).
2. If that doesn't help, **Reset Icon** and re-add it.
3. If icons are missing entirely across all tiles, check
   `~/Vivaldi-Swift/logs/` for a `StorageManager` migration warning — this
   can happen if a very old (pre-v4) icon schema failed to migrate. Please
   open an issue with the log output if you see this; it's not expected.

---

## I want to fully revert to stock Vivaldi

Run the uninstaller for your platform — it restores your most recent
`window.html` backup automatically:

```bash
./install/uninstall-linux.sh --purge     # or uninstall-macos.sh
```
```powershell
.\install\uninstall-windows.ps1 -Purge
```

`--purge`/`-Purge` also removes `~/Vivaldi-Swift` entirely, including logs
and backups. Omit it if you want to keep backups around in case you
reinstall later.

---

## Still stuck?

Open an issue with:

- Your OS and exact Vivaldi version (Help → About Vivaldi)
- The relevant log file contents
- Whether you're on a stable or snapshot Vivaldi build
- Any other Vivaldi modifications you have installed alongside this one
