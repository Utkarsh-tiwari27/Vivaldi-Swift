#!/usr/bin/env bash
#
# Vivaldi Swift — macOS Installer
# ----------------------------------------------------------------------------
# Sets up ~/Vivaldi-Swift, copies the CSS/JS payload and patch engine into
# it, applies the patch to a detected Vivaldi.app, and installs a
# LaunchAgent that keeps Vivaldi Swift patched and quietly up to date on
# its own — no manual update command required.
#
# Usage:
#   ./install-macos.sh [--yes] [--no-auto-patch]
# ----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

MOD_DIR="$HOME/Vivaldi-Swift"
ASSUME_YES=0
INSTALL_AUTO_UPDATE=1
PLIST_LABEL="com.vivaldiswift.autoupdate"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

usage() {
    cat <<EOF
Vivaldi Swift — macOS Installer

Usage: $(basename "$0") [options]

Options:
  --yes              Non-interactive mode (auto-confirm all prompts)
  --no-auto-patch     Skip installing the LaunchAgent auto-update job
  -h, --help          Show this help text
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yes) ASSUME_YES=1; shift ;;
        --no-auto-patch) INSTALL_AUTO_UPDATE=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

banner "Vivaldi Swift Installer"

# ----------------------------------------------------------------------------
# 1. Architecture info (informational only — same Resources layout on both)
# ----------------------------------------------------------------------------
ARCH="$(uname -m)"
ok "Detecting operating system"
if [ "$ARCH" = "arm64" ]; then
    step "macOS (Apple Silicon)"
else
    step "macOS (Intel)"
fi

# ----------------------------------------------------------------------------
# 2. Detect Vivaldi.app
# ----------------------------------------------------------------------------
APP_PATH=""
for candidate in "/Applications/Vivaldi.app" "$HOME/Applications/Vivaldi.app"; do
    if [ -d "$candidate" ]; then
        APP_PATH="$candidate"
        break
    fi
done

if [ -z "$APP_PATH" ] && command -v brew >/dev/null 2>&1; then
    brew_prefix="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
    if [ -d "$brew_prefix/Caskroom/vivaldi" ]; then
        found="$(find "$brew_prefix/Caskroom/vivaldi" -maxdepth 2 -name "Vivaldi.app" 2>/dev/null | head -n 1)"
        [ -n "$found" ] && APP_PATH="$found"
    fi
fi

if [ -z "$APP_PATH" ]; then
    fail "Vivaldi.app was not found in /Applications, ~/Applications, or Homebrew Caskroom. Install Vivaldi first: https://vivaldi.com/download/"
fi
ok "Detecting Vivaldi installation"
step "$APP_PATH"

# ----------------------------------------------------------------------------
# 3. Create the Vivaldi-Swift directory layout
# ----------------------------------------------------------------------------
mkdir -p "$MOD_DIR"/{css,js,icons,backups,logs,bin/lib}
ok "Creating directories"
step "$MOD_DIR"

# ----------------------------------------------------------------------------
# 4. Copy payload files
# ----------------------------------------------------------------------------
cp -f "$REPO_ROOT/css/vivaldi_swift.css" "$MOD_DIR/vivaldi_swift.css"
ok "Installing CSS"

cp -f "$REPO_ROOT/js/custom.js" "$MOD_DIR/custom.js"
ok "Installing JavaScript"

if [ -d "$REPO_ROOT/icons" ]; then
    cp -rf "$REPO_ROOT/icons/." "$MOD_DIR/icons/" 2>/dev/null || true
fi

# ----------------------------------------------------------------------------
# 5. Install the patch engine + auto-updater into $MOD_DIR/bin, and record
#    which repository snapshot this install came from.
# ----------------------------------------------------------------------------
cp -f "$SCRIPT_DIR/lib/common.sh" "$MOD_DIR/bin/lib/common.sh"
cp -f "$SCRIPT_DIR/patch/patch-macos.sh" "$MOD_DIR/bin/patch-macos.sh"
cp -f "$SCRIPT_DIR/update-macos.sh" "$MOD_DIR/bin/update-macos.sh"
cp -f "$SCRIPT_DIR/uninstall-macos.sh" "$MOD_DIR/bin/uninstall-macos.sh"
chmod +x "$MOD_DIR/bin/patch-macos.sh" "$MOD_DIR/bin/update-macos.sh" "$MOD_DIR/bin/uninstall-macos.sh"

if sha="$(remote_repo_sha)" && [ -n "$sha" ]; then
    echo "$sha" > "$MOD_DIR/.repo-sha"
fi

# ----------------------------------------------------------------------------
# 6. Register the background auto-update service. It reapplies the patch
#    and quietly syncs new repository changes on its own — there is no
#    manual update command.
# ----------------------------------------------------------------------------
if [ "$INSTALL_AUTO_UPDATE" -eq 1 ]; then
    mkdir -p "$HOME/Library/LaunchAgents"

    cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$MOD_DIR/bin/update-macos.sh</string>
        <string>--app-path</string>
        <string>$APP_PATH</string>
        <string>--quiet</string>
    </array>
    <key>StartInterval</key>
    <integer>86400</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$MOD_DIR/logs/launchagent.log</string>
    <key>StandardErrorPath</key>
    <string>$MOD_DIR/logs/launchagent.log</string>
</dict>
</plist>
EOF

    launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
    launchctl unload "$HOME/Library/LaunchAgents/com.vivaldiswift.patch.plist" >/dev/null 2>&1 || true
    rm -f "$HOME/Library/LaunchAgents/com.vivaldiswift.patch.plist" 2>/dev/null || true

    ok "Installing auto-update service"
    if launchctl load "$PLIST_PATH" >/dev/null 2>&1; then
        step "LaunchAgent (runs daily; the script self-gates so login runs are cheap)"
    else
        warn "Could not load the LaunchAgent automatically. Run: launchctl load $PLIST_PATH"
    fi
else
    ok "Installing auto-update service"
    step "auto-update skipped (--no-auto-patch)"
fi

# ----------------------------------------------------------------------------
# 7. Apply the patch (backs up window.html, injects CSS/JS, then verifies —
#    automatically rolling back if verification fails)
# ----------------------------------------------------------------------------
PATCH_ARGS=("--mod-dir" "$MOD_DIR" "--app-path" "$APP_PATH")
[ "$ASSUME_YES" -eq 1 ] && PATCH_ARGS+=("--yes")

if ! "$MOD_DIR/bin/patch-macos.sh" "${PATCH_ARGS[@]}"; then
    fail "Patch failed. See $MOD_DIR/logs/patch-macos.log for details."
fi

# ----------------------------------------------------------------------------
# Done
# ----------------------------------------------------------------------------
ok "Done"
echo "$HR"
echo
echo "Final Step"
echo "$HR"
echo
echo "  Open Vivaldi and go to:"
echo
echo "    Settings"
echo "      ↓"
echo "    Appearance"
echo "      ↓"
echo "    Custom UI Modifications"
echo "      ↓"
echo "    Select: $MOD_DIR"
echo "      ↓"
echo "    Restart Vivaldi"
echo
echo "$HR"
echo
echo "  Logs    : $MOD_DIR/logs/"
echo "  Backups : $MOD_DIR/backups/"
echo
if command -v xattr >/dev/null 2>&1; then
    echo "If macOS reports Vivaldi as damaged after patching, run:"
    echo "  xattr -cr \"$APP_PATH\""
    echo
fi
echo "Vivaldi Swift updates itself automatically — nothing else to run."
echo "To uninstall, run: install/uninstall-macos.sh"
