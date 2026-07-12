# Installation Guide

This guide covers installing Vivaldi Swift on Linux, macOS, and Windows, what
the installer actually does to your system, and how to update or remove it.

## Requirements

- A working installation of [Vivaldi](https://vivaldi.com/download/) (stable
  or snapshot channel).
- Administrator/root privileges may be required if Vivaldi is installed in a
  system-wide location (e.g. `/opt`, `Program Files`).
- `git` (to clone the repository) or a downloaded copy of a release archive.
- **Windows only:** PowerShell 5.1 or later (included with Windows 10/11).
  You may need to allow script execution for the current session — see
  [Windows notes](#windows-notes) below.

## What the installer does

Every platform installer performs the same sequence:

1. Detects your operating system and Vivaldi installation.
2. Creates `Vivaldi-Swift/` in your home directory with `css/`, `js/`,
   `icons/`, `backups/`, `logs/`, and `bin/` subfolders.
3. Copies `css/vivaldi_swift.css`, `js/custom.js`, the icon library, and
   `version.json` into that directory.
4. Installs the patch service: the patch engine plus a background task
   (systemd timer / LaunchAgent / Task Scheduler) that re-applies the patch
   automatically after Vivaldi updates — since Vivaldi updates overwrite
   `window.html`.
5. Applies the patch: backs up your current `window.html` with a timestamp,
   injects a `<link>` and `<script>` tag referencing the mod files, copies
   the mod files into Vivaldi's own resource directory, then verifies both
   were actually injected. If verification fails, the backup is restored
   automatically and the installer exits with a clear error — it never
   leaves `window.html` in a half-patched state.

Nothing outside `~/Vivaldi-Swift/` and Vivaldi's own resource directory is
touched. No telemetry, no network calls beyond the initial download, and no
browser extension is installed.

## One-line install (recommended)

The fastest way to install: this downloads the latest release, extracts it,
and runs the right platform installer for you.

```bash
# Linux / macOS
bash <(curl -fsSL https://raw.githubusercontent.com/vivaldi-swift/vivaldi-swift/main/install/bootstrap.sh)
```

```powershell
# Windows
irm https://raw.githubusercontent.com/vivaldi-swift/vivaldi-swift/main/install/bootstrap.ps1 | iex
```

> `vivaldi-swift/vivaldi-swift` is a placeholder used throughout this repo
> until it's published — see `install/bootstrap.sh` / `install/bootstrap.ps1`
> for where to swap in the real org/repo.

Prefer to inspect the code first, or need to pass installer flags like
`--no-auto-patch`? Clone the repository and run the platform installer
directly instead — see the per-OS instructions below.

## Linux

```bash
git clone https://github.com/vivaldi-swift/vivaldi-swift.git
cd vivaldi-swift
./install/install-linux.sh
```

- Detects Vivaldi under `/opt` (stable and snapshot `.deb`/`.rpm` installs)
  and Snap installs.
- If Vivaldi is installed system-wide (the common case), the script uses
  `sudo` only for the specific file operations that touch Vivaldi's resource
  directory — never for anything under your home directory.
- Installs a **systemd user timer** (`vivaldi-swift.timer`) that reapplies
  the patch every 6 hours and at login. If systemd user services aren't
  available, it falls back to a **cron** entry.
- Skip the background task with `./install/install-linux.sh --no-auto-patch`.
- Non-interactive installs (e.g. for scripting/dotfiles): `--yes`.

## macOS

```bash
git clone https://github.com/vivaldi-swift/vivaldi-swift.git
cd vivaldi-swift
./install/install-macos.sh
```

- Detects `Vivaldi.app` in `/Applications`, `~/Applications`, and Homebrew's
  Caskroom.
- Works on both Intel and Apple Silicon — the app bundle layout is identical
  on both architectures.
- Re-signs `Vivaldi.app` with an ad-hoc signature after patching so macOS
  Gatekeeper doesn't flag it as "damaged." If you still see that warning,
  run:
  ```bash
  xattr -cr "/Applications/Vivaldi.app"
  ```
- Installs a **LaunchAgent** (`com.vivaldiswift.patch`) that reapplies the
  patch every 6 hours and at login.
- Skip the background task with `./install/install-macos.sh --no-auto-patch`.

## Windows

Open PowerShell (Administrator is recommended if Vivaldi is installed under
`Program Files`) and run:

```powershell
git clone https://github.com/vivaldi-swift/vivaldi-swift.git
cd vivaldi-swift
.\install\install-windows.ps1
```

### Windows notes

If script execution is disabled, allow it for the current session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

- Detects Vivaldi under `Program Files\Vivaldi`,
  `Program Files (x86)\Vivaldi`, and the per-user default install location
  `%LocalAppData%\Vivaldi`.
- Portable installs are supported by pointing the patch engine at an
  explicit path: `.\install\patch\patch-windows.ps1 -InstallDir "D:\Vivaldi"`.
- Installs a **Task Scheduler** task (`VivaldiSwiftPatch`) that reapplies the
  patch every 6 hours and at logon.
- Skip the background task with `.\install\install-windows.ps1 -NoAutoPatch`.

## Verifying the install

Restart Vivaldi. You should immediately see the glass toolbar, redesigned
Speed Dial, and panel styling. If nothing changed, see
[troubleshooting.md](troubleshooting.md).

## Updating

Vivaldi Swift updates in two independent ways:

- **Vivaldi itself updates** → the background task (systemd timer /
  LaunchAgent / Task Scheduler) automatically reapplies the patch, usually
  within a few hours, since Vivaldi updates overwrite `window.html`. You can
  also trigger it manually — see [docs/update-system.md](update-system.md).
- **Vivaldi Swift releases a new version** → run the updater for your
  platform; no manual download required:
  ```bash
  ~/Vivaldi-Swift/bin/update-linux.sh     # or update-macos.sh
  ```
  ```powershell
  & "$env:USERPROFILE\Vivaldi-Swift\bin\update-windows.ps1"
  ```
  It checks the latest GitHub Release's `version.json` against your
  installed version, exits immediately if you're already up to date, and
  otherwise downloads, replaces the CSS/JS/patch engine, and reapplies the
  patch. Your icons, logs, backups, and any local `.local.css`/`.local.js`
  overrides are never touched. See
  [docs/update-system.md](update-system.md#self-updater) for details.

## Uninstalling

```bash
./install/uninstall-linux.sh     # or uninstall-macos.sh
```

```powershell
.\install\uninstall-windows.ps1
```

This restores your most recent `window.html` backup, removes the background
task, and leaves `~/Vivaldi-Swift/logs` and `backups` in place for reference.
Add `--purge` (`-Purge` on Windows) to delete the entire `Vivaldi-Swift`
directory as well.
