<div align="center">

# Vivaldi Swift

**A liquid-glass redesign for the Vivaldi browser.**

Refined spacing. Glass surfaces. Motion that feels native.
Applied through a safe, reversible patch — one command, any platform.

*The browser chrome you already use, redrawn with intent.*

[![Release](https://img.shields.io/github/v/release/Utkarsh-tiwari27/Vivaldi-Swift?style=flat-square)](https://github.com/Utkarsh-tiwari27/Vivaldi-Swift/releases)
[![License](https://img.shields.io/github/license/Utkarsh-tiwari27/Vivaldi-Swift?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20windows-informational?style=flat-square)](#installation)
[![Vivaldi](https://img.shields.io/badge/vivaldi-6.0%2B-orange?style=flat-square)](https://vivaldi.com/download/)

**[Install](#installation) · [Preview](#preview) · [Features](#features) · [Customize](#custom-icons) · [FAQ](#faq)**

</div>

<br>

<!-- Hero GIF -->

<br>

## Preview

<!-- Browser Screenshot -->
<!-- Toolbar Screenshot -->
<!-- Sidebar Screenshot -->
<!-- Speed Dial Screenshot -->

<br>

## Installation

Requires an existing install of [Vivaldi](https://vivaldi.com/download/) (stable or snapshot), version 6.0 or later.

**Linux / macOS**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Utkarsh-tiwari27/Vivaldi-Swift/main/install/bootstrap.sh)
```

**Windows** (PowerShell)

```powershell
irm https://raw.githubusercontent.com/Utkarsh-tiwari27/Vivaldi-Swift/main/install/bootstrap.ps1 | iex
```

The installer detects your OS and Vivaldi install, backs up `window.html`, injects the patch, copies the icon library, and registers a background task that keeps everything reapplied after Vivaldi auto-updates. Nothing outside `~/Vivaldi-Swift/` and Vivaldi's own resource directory is touched — no telemetry, no browser extension.

> **One manual step remains.** Open Vivaldi and go to:
> **Settings → Appearance → Custom UI Modifications → select `Vivaldi-Swift` → Restart Vivaldi**

<details>
<summary><b>Manual install, per-OS details, and flags</b></summary>
<br>

**Manual install (clone + run the platform installer)**

```bash
# Linux
git clone https://github.com/Utkarsh-tiwari27/Vivaldi-Swift.git
cd Vivaldi-Swift
./install/install-linux.sh

# macOS
./install/install-macos.sh
```

```powershell
# Windows (Administrator PowerShell recommended)
git clone https://github.com/Utkarsh-tiwari27/Vivaldi-Swift.git
cd Vivaldi-Swift
.\install\install-windows.ps1
```

**Linux** — detects `.deb`/`.rpm`, and Snap installs under `/opt`. Uses `sudo` only for the file operations that touch Vivaldi's resource directory, never your home directory. Installs a systemd user timer (falls back to cron if unavailable). Skip the background task with `--no-auto-patch`; run unattended with `--yes`.

**macOS** — detects `Vivaldi.app` in `/Applications`, `~/Applications`, and Homebrew's Caskroom. Works on Intel and Apple Silicon. Re-signs the app with an ad-hoc signature after patching; if Gatekeeper still flags it, run `xattr -cr "/Applications/Vivaldi.app"`. Installs a LaunchAgent. Skip it with `--no-auto-patch`.

**Windows** — detects Vivaldi under `Program Files`, `Program Files (x86)`, and the per-user `%LocalAppData%\Vivaldi` path. Portable installs: point the patch engine at an explicit path with `-InstallDir`. Installs a Task Scheduler task. Skip it with `-NoAutoPatch`. If script execution is disabled, run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` first.

**Uninstalling**

```bash
./install/uninstall-linux.sh     # or uninstall-macos.sh
```

```powershell
.\install\uninstall-windows.ps1
```

Restores your most recent `window.html` backup and removes the background task. Logs and backups are kept for reference — add `--purge` (`-Purge` on Windows) to remove everything, including `~/Vivaldi-Swift`.

</details>

<br>

## Features

|  |  |
|---|---|
| **Glass surfaces, everywhere**<br>Toolbar, address bar, dropdowns, Speed Dial, side panel, and tab bar each get a dedicated glass module — not one filter over the whole UI. | **One-line installation**<br>No cloning, no manual downloads. A single command detects your OS, fetches the latest release, and installs everything. |
| **Custom Speed Dial icons**<br>Right-click any tile to upload your own SVG or PNG, reposition and resize it live, or reset it to the site favicon. | **Automatic patching**<br>Vivaldi updates overwrite `window.html`. A scheduled background task reapplies the patch automatically — usually within hours, or immediately at next login. |
| **Cross-platform**<br>One patch engine, three native implementations — Linux, macOS, and Windows all get first-class installers, uninstallers, and updaters. | **Safe by construction**<br>Every patch run backs up `window.html` first and verifies the result. If anything looks wrong, it rolls back automatically. |

Also included: an in-app icon library (toolbar, sidebar, and social sets) and a self-updater that checks `version.json` before downloading anything.

<br>

## Custom Icons

Right-click any Speed Dial tile → **Change Icon** to upload your own artwork, reposition and resize it, or reset it to the site favicon.

- **Formats:** SVG (preferred — scales cleanly, sanitized and ID-namespaced automatically) or PNG (transparent background, exported at 2×–3× target size).
- **Recommended size:** design at 64×64 or 128×128; the layout system scales it down per tile.
- **Folders:** `icons/toolbar/`, `icons/sidebar/`, `icons/social/`, `icons/custom/`.
- **Good sources:** [thesvg.org](https://thesvg.org/), [Heroicons](https://heroicons.com/), [Lucide](https://lucide.dev/), [Tabler Icons](https://tabler.io/icons) — always verify the license before committing icons to a repository.

<br>

## Updating

Vivaldi Swift updates on two independent fronts:

- **Vivaldi updates itself** → the background task reapplies the patch automatically, since Vivaldi overwrites `window.html` on every update.
- **Vivaldi Swift releases a new version** → run the self-updater:

```bash
~/Vivaldi-Swift/bin/update-linux.sh     # or update-macos.sh
```

```powershell
& "$env:USERPROFILE\Vivaldi-Swift\bin\update-windows.ps1"
```

It checks the latest release's `version.json` against your installed version and exits immediately if you're already current — otherwise it replaces the CSS, JS, and patch engine, then reapplies the patch. Icons, logs, backups, and local overrides are never touched.

<br>

## Roadmap

**Shipped** — cross-platform installers, uninstallers, and self-updaters · per-OS patch engines with backup, verification, and rollback · scheduled automatic patch reapplication · Speed Dial custom icon system · one-line bootstrap installers.

**In progress** — broader screenshot and preview coverage · community-contributed icon sets.

**Planned** — theme presets · dynamic accent colors · wallpaper-aware color extraction · plugin API.

<br>

## FAQ

<details>
<summary>Is Vivaldi Swift an official Vivaldi project?</summary><br>
No. It's an independent community project, not affiliated with or endorsed by Vivaldi Technologies AS.
</details>

<details>
<summary>Is it safe to use?</summary><br>
Yes. It only patches Vivaldi's UI files, creates automatic backups, and can be fully removed with the uninstall script.
</details>

<details>
<summary>Will Vivaldi updates break it?</summary><br>
No. The patch service reapplies itself automatically after browser updates.
</details>

<details>
<summary>Does it work on Vivaldi Snapshot?</summary><br>
Yes. Both Stable and Snapshot builds are supported.
</details>

<details>
<summary>Can I use only the CSS or only the JavaScript?</summary><br>
Yes. Both components work independently for a manual setup.
</details>

<details>
<summary>Does it affect browser performance?</summary><br>
No noticeable impact. The CSS and JavaScript are lightweight by design.
</details>

<details>
<summary>Can I customize it further?</summary><br>
Absolutely — the stylesheet is modular. Adjust colors, spacing, and blur, or add your own icons.
</details>

<br>

## Troubleshooting

<details>
<summary>Vivaldi wasn't detected</summary><br>
Install Vivaldi first, or specify its installation path manually.
</details>

<details>
<summary>Permission denied</summary><br>
Run the installer with administrator privileges (<code>sudo</code> or Administrator PowerShell).
</details>

<details>
<summary>Nothing changed after installing</summary><br>
Restart Vivaldi completely. If it still doesn't apply, rerun the patch script.
</details>

<details>
<summary>The UI disappeared after a Vivaldi update</summary><br>
Expected — the auto-patcher restores it automatically, or you can run the patch script manually.
</details>

<details>
<summary>Custom icons aren't showing</summary><br>
Restart Vivaldi, or reset the affected icon.
</details>

<details>
<summary>How do I uninstall Vivaldi Swift?</summary><br>
Run the uninstall script for your operating system — it restores your original UI.
</details>

Still stuck? [Open a GitHub Issue](https://github.com/Utkarsh-tiwari27/Vivaldi-Swift/issues) with your OS, Vivaldi version, and a brief description.

<br>

## License

Released under the [MIT License](LICENSE).

Vivaldi Swift is an independent project and is not affiliated with, endorsed by, or sponsored by Vivaldi Technologies AS.

<br>

<div align="center">

*Built for people who notice when an interface is right.*

</div>
