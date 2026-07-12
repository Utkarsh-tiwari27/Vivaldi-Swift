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
<sub><b> Custom Speed Dial icon</b></sub>
</td>
</tr>
</table>

<br>

## Overview

This custom css and js mod transforms your vivaldi browser ui into liquid glass design along with an additional feature of letting users to set high quality custom icons for their speed dial cards.

## Installation

### 🚀 Automatic (Recommended)

### Step 1
Simply copy the command based on your  operating system, paste it into your terminal, and press **Enter**.

The installer will automatically set everything up.

#### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/Utkarsh-tiwari27/Vivaldi-Swift/main/install/bootstrap.ps1 | iex
```

#### macos / linux

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Utkarsh-tiwari27/Vivaldi-Swift/main/install/bootstrap.sh)
```

### Step 2

> [!IMPORTANT]
> **One manual step is still required.**
>
> After the installer finishes:
>
> 1. Open vivaldi -> paste**`vivaldi://experiments`** into address bar hit enter.
> 2. Search and Enable **Allow CSS Modifications**
> 3. Open **Settings → Appearance**
> 4. Under **Custom UI Modifications**, select the **Vivaldi-Swift** folder created after installtion in your home directory.
> 5. Restart Vivaldi.


### Step 3 - Custom Icons

To set custom icons on speed dial card

Right-click any Speed Dial card → **Change Icon** to upload your own icon.

- **Format** — SVG preferred (sanitized and ID-namespaced automatically), or PNG 

you can get high quality SVG icons from: [thesvg.org](https://thesvg.org/) 

<br>
---

### 🛠️ Manual Installation

<details>
<summary><strong>Platform-specific installation</strong></summary>

<br>

#### Windows

```powershell
git clone https://github.com/Utkarsh-tiwari27/Vivaldi-Swift.git

cd Vivaldi-Swift

.\install\install-windows.ps1
```

#### Linux

```bash
git clone https://github.com/Utkarsh-tiwari27/Vivaldi-Swift.git

cd Vivaldi-Swift

./install/install-linux.sh
```

#### macOS

```bash
git clone https://github.com/Utkarsh-tiwari27/Vivaldi-Swift.git

cd Vivaldi-Swift

./install/install-macos.sh
```

### Platform Notes

**Linux**

- Detects `.deb`, `.rpm`, and Snap installations.
- Uses `sudo` only when modifying Vivaldi's installation.
- Installs a systemd user timer (cron fallback).
- Optional flags:
  - `--no-auto-patch`
  - `--yes`

**macOS**

- Detects installations in `/Applications`, `~/Applications`, and Homebrew.
- Supports both Intel and Apple Silicon.
- Automatically re-signs the application after patching.
- Optional flag:
  - `--no-auto-patch`

**Windows**

- Detects installations in `Program Files`, `Program Files (x86)`, and `%LocalAppData%`.
- Supports portable installations via `-InstallDir`.
- Creates a Task Scheduler job for automatic patching.
- If PowerShell blocks scripts:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

</details>

---

### 🗑️ Uninstall

<details>
<summary><strong>To Uninstall the vivaldi swift setup simply run below commands</strong></summary>

<br>

#### Linux / macOS

```bash
./install/uninstall-linux.sh
# or
./install/uninstall-macos.sh
```

#### Windows

```powershell
.\install\uninstall-windows.ps1
```

The uninstaller restores the latest backup, removes the automatic patch task, and returns Vivaldi to its original state.

</details>

## Features

|  |  |
|---|---|
| **Glass surfaces, everywhere**<br>Toolbar, address bar, dropdowns, Speed Dial, side panel, and tab bar each get a dedicated glass module — not one filter over the whole UI. **Custom Speed Dial icons**<br>Upload your own SVG or PNG per tile, reposition and resize it live, or reset it to the site favicon. |
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
