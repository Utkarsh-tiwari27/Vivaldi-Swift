<!--
  README_PLACEHOLDER.md
  ----------------------
  This is a working outline for the real README.md, which will be written
  and polished separately before the repository goes public. It exists so
  the structure, required assets, and copy slots are agreed on ahead of time.

  Once the real README is written, delete this file (or rename it to
  README.md and remove this comment block).
-->

# Vivaldi Swift

<!-- BADGES -->
<p align="center">
  <img alt="License" src="https://img.shields.io/github/license/vivaldi-swift/vivaldi-swift">
  <img alt="Latest release" src="https://img.shields.io/github/v/release/vivaldi-swift/vivaldi-swift">
  <img alt="Platforms" src="https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20windows-blue">
  <img alt="Vivaldi" src="https://img.shields.io/badge/vivaldi-6.x%2B-orange">
  <!-- Add once CI exists: build status badge -->
</p>

<!-- PROJECT SUMMARY (1–2 sentences, punchy, no jargon) -->
> A modern, Apple-inspired glass redesign for the Vivaldi browser — refined
> spacing, liquid-glass surfaces, and native-feeling motion, applied through
> a safe, reversible CSS/JS patch with one-command install on Linux, macOS,
> and Windows.

<!-- HERO SCREENSHOT — required before publishing -->
<!-- ![Vivaldi Swift hero screenshot](screenshots/hero.png) -->

---

## Section outline for the final README

1. **Hero section**
   - One-line pitch (above)
   - Hero screenshot or short GIF of the Speed Dial / toolbar in motion
   - Badges (license, release, platform support)

2. **Feature highlights**
   - Toolbar & address bar glass material
   - Address bar + search dropdown redesign
   - Speed Dial tile system + custom icon editor
   - Panel (bookmarks/notes/downloads) glass theme
   - Tab bar material system
   - Bullet list, each with a small before/after screenshot

3. **Screenshots gallery**
   - Grid of 4–6 screenshots: toolbar, speed dial, panel, tab bar, context
     menu / icon editor, dark mode if applicable
   - Required files (see `screenshots/` — currently empty, populate before
     publishing):
     - `screenshots/hero.png`
     - `screenshots/toolbar.png`
     - `screenshots/speed-dial.png`
     - `screenshots/panel.png`
     - `screenshots/tab-bar.png`
     - `screenshots/icon-editor.png`

4. **Installation** (placeholder — link out to docs/installation.md for full detail)
   - Requirements (Vivaldi version floor, OS versions)
   - One-line install (recommended):
     ```bash
     # Linux / macOS
     bash <(curl -fsSL https://raw.githubusercontent.com/vivaldi-swift/vivaldi-swift/main/install/bootstrap.sh)
     ```
     ```powershell
     # Windows
     irm https://raw.githubusercontent.com/vivaldi-swift/vivaldi-swift/main/install/bootstrap.ps1 | iex
     ```
   - Manual install (clone + run the platform installer directly):
     ```bash
     # Linux / macOS
     git clone https://github.com/vivaldi-swift/vivaldi-swift.git
     cd vivaldi-swift
     ./install/install-linux.sh     # or ./install/install-macos.sh
     ```
     ```powershell
     # Windows (PowerShell, as Administrator recommended)
     git clone https://github.com/vivaldi-swift/vivaldi-swift.git
     cd vivaldi-swift
     .\install\install-windows.ps1
     ```
   - Link to `docs/installation.md` for full walkthrough + troubleshooting

5. **Updating**
   - Explain the auto-reapply service (systemd timer / LaunchAgent / Task
     Scheduler) installed by default, which keeps the current CSS/JS applied
     after Vivaldi updates
   - Explain the self-updater (`bin/update-linux.sh` / `update-macos.sh` /
     `update-windows.ps1`) for pulling a new Vivaldi Swift release — no
     manual ZIP download needed, and it detects "already up to date"
     automatically

6. **Uninstalling**
   - One command per OS, points at `install/uninstall-*`
   - Note that original `window.html` is restored from backup

7. **Customization**
   - Link to `docs/icons.md` for custom Speed Dial icons
   - Mention CSS variables / module structure, link to `docs/architecture.md`

8. **FAQ / Troubleshooting**
   - Short teaser + links to `docs/faq.md` and `docs/troubleshooting.md`

9. **Contributing**
   - Short teaser + link to `CONTRIBUTING.md`

10. **License & disclaimer**
    - MIT license badge/link
    - Standard "not affiliated with Vivaldi Technologies AS" disclaimer

<!-- REQUIRED BEFORE PUBLISHING -->
## Publishing checklist

- [ ] Write final `README.md` from this outline
- [ ] Capture and add all screenshots listed above
- [ ] Record a short demo GIF for the hero section (optional but recommended)
- [ ] Fill in real GitHub org/repo URLs (badges + clone commands currently
      point at placeholder `vivaldi-swift/vivaldi-swift`, as do the `REPO`/
      `$Repo` placeholders in `install/bootstrap.sh`, `install/bootstrap.ps1`,
      and `install/update-{linux,macos,windows}.*`)
- [ ] Confirm each GitHub Release includes `vivaldi-swift.zip` and
      `version.json` as release assets (the bootstrap and updater scripts
      download them directly via `releases/latest/download/...`)
- [ ] Tag `v1.0.0` release once README + screenshots are in place
- [ ] Delete this file
