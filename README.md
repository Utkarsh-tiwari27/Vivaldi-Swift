<div align="center">

<!-- Logo -->
<!-- <img src="assets/logo.svg" width="88" alt="Vivaldi Swift" /> -->

# Vivaldi Swift

**A liquid‑glass redesign for the Vivaldi browser.**

<!-- Hero GIF — toolbar, Speed Dial, and panel in motion -->
<!-- ![Vivaldi Swift hero preview](screenshots/hero.gif) -->

<p>
  <img alt="Version" src="https://img.shields.io/badge/version-1.0.0-blue?style=flat-square">
  <img alt="License" src="https://img.shields.io/github/license/GITHUB_USERNAME/vivaldi-swift?style=flat-square">
  <img alt="Platform" src="https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20windows-informational?style=flat-square">
  <img alt="Vivaldi" src="https://img.shields.io/badge/vivaldi-6.0%2B-orange?style=flat-square">
  <img alt="Release" src="https://img.shields.io/github/v/release/GITHUB_USERNAME/vivaldi-swift?style=flat-square">
  <img alt="Last commit" src="https://img.shields.io/github/last-commit/GITHUB_USERNAME/vivaldi-swift?style=flat-square">
  <img alt="Stars" src="https://img.shields.io/github/stars/GITHUB_USERNAME/vivaldi-swift?style=flat-square">
</p>

Refined spacing. Glass surfaces. Motion that feels native.
Applied to Vivaldi through a safe, reversible patch — one command, any platform.

> *The browser chrome you already use, redrawn with intent.*

**[Install](#installation)** · **[Preview](#preview)** · **[Features](#features)** · **[Docs](#documentation)**

</div>

<br>

## Contents

- [Installation](#installation)
- [Preview](#preview)
- [Features](#features)
- [Vivaldi Swift vs. Stock Vivaldi](#vivaldi-swift-vs-stock-vivaldi)
- [Why Vivaldi Swift Exists](#why-vivaldi-swift-exists)
- [Repository Structure](#repository-structure)
- [Documentation](#documentation)
- [Custom Icons](#custom-icons)
- [Updating](#updating)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

<br>

## Installation

Requires an existing install of [Vivaldi](https://vivaldi.com/download/) (stable or snapshot), version 6.0 or later.

<table>
<tr><td><b>Linux / macOS</b></td></tr>
<tr><td>

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GITHUB_USERNAME/vivaldi-swift/main/install/bootstrap.sh)
```

</td></tr>
<tr><td><b>Windows</b> (PowerShell)</td></tr>
<tr><td>

```powershell
irm https://raw.githubusercontent.com/GITHUB_USERNAME/vivaldi-swift/main/install/bootstrap.ps1 | iex
```

</td></tr>
</table>

The installer detects your OS and Vivaldi installation, backs up `window.html`, injects the patch, copies the icon library, and registers a background task that keeps everything reapplied after Vivaldi auto-updates. Nothing outside `~/Vivaldi-Swift/` and Vivaldi's own resource directory is touched — no telemetry, no browser extension.

> [!IMPORTANT]
> **One manual step remains after installing.** Open Vivaldi and go to:
>
> **Settings → Appearance → Custom UI Modifications → select `Vivaldi-Swift` → Restart Vivaldi**

Prefer to inspect the code first, need installer flags like `--no-auto-patch`, or want the full per‑OS walkthrough? See **[docs/installation.md](docs/installation.md)**.

<details>
<summary>Manual install (clone + run the platform installer)</summary>

```bash
# Linux
git clone https://github.com/GITHUB_USERNAME/vivaldi-swift.git
cd vivaldi-swift
./install/install-linux.sh

# macOS
./install/install-macos.sh
```

```powershell
# Windows (Administrator PowerShell recommended)
git clone https://github.com/GITHUB_USERNAME/vivaldi-swift.git
cd vivaldi-swift
.\install\install-windows.ps1
```

</details>

<br>

## Preview

<!-- Screenshot placeholders — replace before publishing -->

| Toolbar & Address Bar | Speed Dial |
|:---:|:---:|
| ![Toolbar](screenshots/toolbar.png) | ![Speed Dial](screenshots/speed-dial.png) |

| Side Panel | Tab Bar |
|:---:|:---:|
| ![Panel](screenshots/panel.png) | ![Tab bar](screenshots/tab-bar.png) |

| Speed Dial Icon Editor |
|:---:|
| ![Icon editor](screenshots/icon-editor.png) |

<br>

## Features

<table>
<tr>
<td width="50%" valign="top">

**Glass surfaces, everywhere**
Toolbar, address bar, address dropdown, search dropdown, Speed Dial, side panel, and tab bar each get a dedicated, self-contained glass module — not one filter slapped over the whole UI.

**Custom Speed Dial icons**
Right-click any tile to upload your own SVG or PNG, reposition and resize it live, and reset it back to the site favicon at any time.

**Cross-platform**
One patch engine, three native implementations — Linux, macOS, and Windows all get first-class installers, uninstallers, and updaters.

</td>
<td width="50%" valign="top">

**One-line installation**
No cloning, no manual downloads. A single command detects your OS, fetches the latest release, and installs everything.

**Automatic patching**
Vivaldi updates overwrite `window.html`. A scheduled background task (systemd timer, LaunchAgent, or Task Scheduler) reapplies the patch automatically — usually within hours, or immediately at next login.

**Safe by construction**
Every patch run backs up `window.html` first and verifies the result. If anything looks wrong, it rolls back automatically — never a half-patched browser.

</td>
</tr>
</table>

**Also included:** an in-app icon library (toolbar, sidebar, and social sets), a self-updater that checks `version.json` before downloading anything, full uninstall scripts that restore your original UI, and a documentation set covering every part of the system.

<br>

## Vivaldi Swift vs. Stock Vivaldi

| | Stock Vivaldi | Vivaldi Swift |
|---|:---:|:---:|
| Toolbar & panel styling | Default Chromium chrome | Unified glass material system |
| Speed Dial | Static favicons | Custom SVG/PNG icons, live resize & reposition |
| Design consistency | Per-surface defaults | Shared visual language across toolbar, dropdowns, panel, and tabs |
| Install method | N/A | One-line bootstrap installer |
| Survives Vivaldi updates | — | Automatic, scheduled patch reapplication |
| Cross-platform support | Linux · macOS · Windows | Linux · macOS · Windows |
| Reversible | — | Full uninstaller restores original `window.html` |
| Documentation | Official docs | [Dedicated docs](#documentation) for architecture, icons, updates, and troubleshooting |

<br>

## Why Vivaldi Swift Exists

Vivaldi's interface is already one of the most customizable in any browser — but customization is usually additive: a theme here, a CSS snippet there. Vivaldi Swift instead treats the toolbar, dropdowns, Speed Dial, panel, and tab bar as one interconnected surface, and redesigns them together.

That's the actual goal: not a glass *effect*, but glass used consistently — the same materials, spacing, and motion language applied everywhere the browser draws its own UI, so nothing feels bolted on.

<br>

## Repository Structure

```
vivaldi-swift/
├── css/
│   └── vivaldi_swift.css     Production stylesheet (single-file, module sections)
├── js/
│   └── custom.js             Speed Dial custom-icon framework
├── icons/
│   ├── toolbar/               Icons matching the toolbar/address bar style
│   ├── sidebar/                Icons for the side panel
│   ├── social/                 Common social/site icons for Speed Dial tiles
│   └── custom/                 User-contributed or project-specific icons
├── install/
│   ├── bootstrap.sh / bootstrap.ps1        One-line installers
│   ├── install-{linux,macos,windows}.*     Platform installers
│   ├── update-{linux,macos,windows}.*      Self-updaters
│   ├── uninstall-{linux,macos,windows}.*   Uninstallers
│   └── patch/                              Per-OS patch engines
├── docs/                       Installation, architecture, icons, FAQ, troubleshooting, updates
├── screenshots/                Repository preview images
├── version.json                Version metadata read by the updater
└── README.md
```

<br>

## Documentation

| Guide | Covers |
|---|---|
| [Installation](docs/installation.md) | Requirements, per-OS install steps, verifying, updating, uninstalling |
| [Architecture](docs/architecture.md) | Why patching is necessary, CSS module layout, the `custom.js` framework, injection hierarchy |
| [Icons](docs/icons.md) | Supported formats, recommended sizes, folder structure, icon sources |
| [Update System](docs/update-system.md) | How automatic reapplication works, manual reapplication, the self-updater |
| [Troubleshooting](docs/troubleshooting.md) | Common install/patch problems, organized by symptom |
| [FAQ](docs/faq.md) | Safety, performance, snapshot builds, and other common questions |
| [License](LICENSE) | MIT |

<br>

## Custom Icons

The Speed Dial framework in `js/custom.js` includes a full custom icon system — right-click any tile → **Change Icon** to upload your own artwork, reposition and resize it, or reset it to the site's favicon.

- **Formats:** SVG (preferred — scales cleanly, automatically sanitized and ID-namespaced) and PNG (use a transparent background, export at 2×–3× target size).
- **Recommended size:** design at 64×64 or 128×128; the layout system scales down per tile.
- **Folder structure:** icons live under `icons/toolbar/`, `icons/sidebar/`, `icons/social/`, and `icons/custom/` — see [icons/README.md](icons/README.md).
- **Good sources:** [thesvg.org](https://thesvg.org/), [Heroicons](https://heroicons.com/), [Lucide](https://lucide.dev/), and [Tabler Icons](https://tabler.io/icons) — always verify the license before committing icons to a repository.

Full workflow and details: **[docs/icons.md](docs/icons.md)**.

<br>

## Updating

Vivaldi Swift updates independently on two fronts:

- **Vivaldi updates itself** → a scheduled background task (systemd timer on Linux, LaunchAgent on macOS, Task Scheduler on Windows) reapplies the patch automatically, since Vivaldi overwrites `window.html` on every update.
- **Vivaldi Swift releases a new version** → run the self-updater for your platform:

  ```bash
  ~/Vivaldi-Swift/bin/update-linux.sh     # or update-macos.sh
  ```

  ```powershell
  & "$env:USERPROFILE\Vivaldi-Swift\bin\update-windows.ps1"
  ```

  It checks the latest release's `version.json` against your installed version and exits immediately if you're already current — otherwise it replaces the CSS, JS, and patch engine, then reapplies the patch. Icons, logs, backups, and local overrides are never touched.

Full detail: **[docs/update-system.md](docs/update-system.md)**.

<br>

## Roadmap

**Completed**
- Cross-platform installers, uninstallers, and self-updaters for Linux, macOS, and Windows
- Per-OS patch engines with backup, verification, and automatic rollback
- Scheduled automatic patch reapplication (systemd timer, LaunchAgent, Task Scheduler)
- Speed Dial custom icon system with live resize, reposition, and reset
- One-line bootstrap installers
- Full documentation set

**In Progress**
- Broader screenshot and preview coverage
- Community-contributed icon sets

**Planned**
- Theme presets
- Dynamic accent colors
- Wallpaper-aware color extraction
- Plugin API


## License

Released under the [MIT License](LICENSE).

Vivaldi Swift is an independent project and is not affiliated with, endorsed by, or sponsored by Vivaldi Technologies AS.

<br>

<div align="center">

*Built for people who notice when an interface is right.*

</div>
