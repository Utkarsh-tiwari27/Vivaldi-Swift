<div align="center">

# Vivaldi Swift

**A liquid-glass redesign for the Vivaldi browser using custom css/js mods.**

Refined spacing, glass surfaces and custom high quality speed dial icons.

[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20windows-informational?style=flat-square)](#installation)
[![Vivaldi](https://img.shields.io/badge/vivaldi-6.0%2B-orange?style=flat-square)](https://vivaldi.com/download/)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

<p>
<a href="#installation">Installation</a> •
<a href="#features">Features</a> •
<a href="#custom-icons">Custom Icons</a> •
<a href="#updating">Updating</a> •
<a href="#faq">FAQ</a>
</p>

</div>

<p align="center">
  <img
    src="https://github.com/user-attachments/assets/6300d09f-cc61-4149-9870-3c789e883129"
    alt="Vivaldi Swift Hero"
    width="400"
  />
</p>

<br>

<table align="center">
<tr>
<td align="center" width="50%">
<img src="https://github.com/user-attachments/assets/eb892458-3671-48e7-8064-c36609c62e05" alt="Vivaldi Swift Browser UI" width="480"><br>
<sub><b>Browser UI</b></sub>
</td>
<td align="center" width="50%">
<img src="https://github.com/user-attachments/assets/2287183f-f30b-47cc-b1fd-9af20c1f3a59" alt="Vivaldi Swift Speed Dial" width="480"><br>
<sub><b>Speed Dial</b></sub>
</td>
</tr>
</table>

<br>

## Installation

Requires an existing install of [Vivaldi](https://vivaldi.com/download/) — stable or snapshot, version 6.0+.

**Linux / macOS**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Utkarsh-tiwari27/Vivaldi-Swift/main/install/bootstrap.sh)
```

**Windows** (PowerShell)

```powershell
irm https://raw.githubusercontent.com/Utkarsh-tiwari27/Vivaldi-Swift/main/install/bootstrap.ps1 | iex
```

One command detects your OS and Vivaldi install, backs up `window.html`, injects the patch, copies the icon library, and schedules automatic reapplication after every Vivaldi update. Nothing outside `~/Vivaldi-Swift/` and Vivaldi's own resource directory is touched — no telemetry, no browser extension.

> [!IMPORTANT]
> One manual step remains. Open Vivaldi and go to
> **Settings → Appearance → Custom UI Modifications → select `Vivaldi-Swift` → Restart Vivaldi**

<details>
<summary><b>Manual install & per-OS details</b></summary>
<br>

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

**Linux** — detects `.deb`/`.rpm` and Snap installs under `/opt`. Uses `sudo` only for operations that touch Vivaldi's resource directory, never your home directory. Installs a systemd user timer (cron fallback). Skip it with `--no-auto-patch`; run unattended with `--yes`.

**macOS** — detects `Vivaldi.app` in `/Applications`, `~/Applications`, and Homebrew's Caskroom. Works on Intel and Apple Silicon. Re-signs the app with an ad-hoc signature after patching; if Gatekeeper still flags it, run `xattr -cr "/Applications/Vivaldi.app"`. Installs a LaunchAgent, skippable with `--no-auto-patch`.

**Windows** — detects Vivaldi under `Program Files`, `Program Files (x86)`, and `%LocalAppData%\Vivaldi`. Portable installs: point the patch engine at an explicit path with `-InstallDir`. Installs a Task Scheduler task, skippable with `-NoAutoPatch`. If script execution is disabled: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`.

</details>

<details>
<summary><b>Uninstalling</b></summary>
<br>

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
| **Glass surfaces, everywhere**<br>Toolbar, address bar, dropdowns, Speed Dial, side panel, and tab bar each get a dedicated glass module — not one filter over the whole UI. | **One-line installation**<br>No cloning, no manual downloads. A single command detects your OS and installs everything. |
| **Custom Speed Dial icons**<br>Upload your own SVG or PNG per tile, reposition and resize it live, or reset it to the site favicon. | **Automatic patching**<br>Vivaldi updates overwrite `window.html`. A scheduled background task reapplies the patch on its own. |
| **Cross-platform**<br>One patch engine, three native implementations — Linux, macOS, and Windows all get first-class tooling. | **Safe by construction**<br>Every patch run backs up `window.html` and verifies the result, rolling back automatically if anything's off. |

<br>

## Custom Icons

Right-click any Speed Dial tile → **Change Icon** to upload your own artwork, reposition and resize it, or reset it to the site favicon.

- **Format** — SVG preferred (sanitized and ID-namespaced automatically), or PNG with a transparent background.
- **Size** — design at 64×64 or 128×128; the layout system scales it per tile.
- **Folders** — `icons/toolbar/`, `icons/sidebar/`, `icons/social/`, `icons/custom/`.

Good sources: [thesvg.org](https://thesvg.org/) · [Heroicons](https://heroicons.com/) · [Lucide](https://lucide.dev/) · [Tabler Icons](https://tabler.io/icons) — verify the license before committing icons to a repo.

<br>

## Updating

Vivaldi Swift updates on two independent fronts:

- **Vivaldi updates itself** → the background task reapplies the patch automatically.
- **Vivaldi Swift releases a new version** → run the self-updater:

```bash
~/Vivaldi-Swift/bin/update-linux.sh     # or update-macos.sh
```

```powershell
& "$env:USERPROFILE\Vivaldi-Swift\bin\update-windows.ps1"
```

> [!NOTE]
> The updater checks `version.json` first and exits immediately if you're already current — icons, logs, backups, and local overrides are never touched.

<br>

## Roadmap

**✅ Completed**
- Cross-platform installers, uninstallers, and self-updaters
- Per-OS patch engines with backup, verification, and rollback
- Scheduled automatic patch reapplication
- Speed Dial custom icon system
- One-line bootstrap installers

**🚧 In Progress**
- Broader screenshot and preview coverage
- Community-contributed icon sets

**💡 Planned**
- Theme presets
- Dynamic accent colors
- Wallpaper-aware color extraction
- Plugin API

<br>

## FAQ

<details>
<summary>Is Vivaldi Swift an official Vivaldi project?</summary><br>
No — it's an independent community project, not affiliated with or endorsed by Vivaldi Technologies AS.
</details>

<details>
<summary>Is it safe to use?</summary><br>
Yes. It only patches Vivaldi's UI files, creates automatic backups, and can be fully removed with the uninstall script.
</details>

<details>
<summary>Will Vivaldi updates break it?</summary><br>
No — the patch service reapplies itself automatically after browser updates.
</details>

<details>
<summary>Does it work on Vivaldi Snapshot?</summary><br>
Yes, both Stable and Snapshot builds are supported.
</details>

<details>
<summary>Can I use only the CSS or only the JavaScript?</summary><br>
Yes, both components work independently for a manual setup.
</details>

<details>
<summary>Does it affect browser performance?</summary><br>
No noticeable impact — the CSS and JavaScript are lightweight by design.
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
Run the installer with elevated privileges (<code>sudo</code> or Administrator PowerShell).
</details>

<details>
<summary>Nothing changed after installing</summary><br>
Restart Vivaldi completely. If it still doesn't apply, rerun the patch script.
</details>

<details>
<summary>The UI disappeared after a Vivaldi update</summary><br>
Expected — the auto-patcher restores it shortly, or run the patch script manually.
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
