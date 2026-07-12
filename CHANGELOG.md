# Changelog

All notable changes to Vivaldi Swift are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Cross-platform installers (`install-linux.sh`, `install-macos.sh`, `install-windows.ps1`)
  with distro/OS detection, backup creation, and clear success/error messaging.
- Cross-platform patch engines under `install/patch/` supporting Linux (`/opt`, snap),
  macOS (`/Applications`, `~/Applications`, Homebrew Cask), and Windows
  (Program Files, Program Files (x86), per-user LocalAppData installs, and portable
  installs via an explicit path).
- Automatic patch re-application after Vivaldi updates: systemd user timer (with cron
  fallback) on Linux, a LaunchAgent on macOS, and a Task Scheduler task on Windows.
- Timestamped `window.html` backups and matching uninstall scripts that restore the
  original file for each platform.
- Structured logging of all patch operations (timestamp, Vivaldi version, patch
  status, errors) under `~/Vivaldi-Swift/logs/`.
- Project documentation: installation guide, architecture overview, FAQ,
  troubleshooting guide, and icon authoring guide.
- Community health files: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`,
  issue templates, and a pull request template.
- Cleaner installer terminal output: a consistent checklist-style banner (colored
  unicode checkmarks where the terminal supports them, plain-text fallback
  otherwise) and a "Final Step" panel walking through Settings → Appearance →
  Custom UI Modifications.
- Post-patch verification in every patch engine: after injecting the CSS/JS
  references and copying the mod files, the patch verifies both actually landed
  and automatically restores the pre-patch backup — with a clear, specific error
  message — if verification fails. Backups are also verified non-empty
  immediately after creation, before any modification is made.
- `version.json` at the repository root (version, minimum supported Vivaldi
  version, patch schema version), copied into `~/Vivaldi-Swift/` on install and
  used by the updater to cheaply detect "already up to date".
- Self-updater scripts (`install/update-linux.sh`, `install/update-macos.sh`,
  `install/update-windows.ps1`) that pull the latest GitHub Release, replace
  the CSS/JS/patch engine, and reapply the patch — without ever touching user
  icons, logs, backups, or local `.local.css`/`.local.js` overrides.
- One-line bootstrap installers (`install/bootstrap.sh` for Linux/macOS,
  `install/bootstrap.ps1` for Windows) that download the latest release,
  extract it, and run the right platform installer — so first-time install
  never requires cloning the repo or downloading a ZIP by hand.

### Notes
- This is the first public-release packaging of Vivaldi Swift. The CSS and JS
  modules themselves (toolbar, address bar, speed dial, panel, tab bar) are carried
  over unmodified from the pre-release working build; see `css/vivaldi_swift.css`
  and `js/custom.js` for their internal module-level version history.
- The GitHub org/repo used by the one-line installers and the self-updater
  (`vivaldi-swift/vivaldi-swift`) is a placeholder — see the publishing
  checklist in `README_PLACEHOLDER.md`.

[Unreleased]: https://github.com/vivaldi-swift/vivaldi-swift/compare/main...HEAD
