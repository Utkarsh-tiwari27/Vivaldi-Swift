#!/usr/bin/env bash
#
# Vivaldi Swift — macOS Uninstaller
# ----------------------------------------------------------------------------
# Restores the most recent window.html backup for the detected Vivaldi.app,
# removes the LaunchAgent, and optionally deletes ~/Vivaldi-Swift.
#
# Usage:
#   ./uninstall-macos.sh [--yes] [--purge]
# ----------------------------------------------------------------------------

set -euo pipefail

MOD_DIR="$HOME/Vivaldi-Swift"
PLIST_LABEL="com.vivaldiswift.patch"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
ASSUME_YES=0
PURGE=0

usage() {
    cat <<EOF
Vivaldi Swift — macOS Uninstaller

Usage: $(basename "$0") [options]

Options:
  --yes     Non-interactive mode (auto-confirm all prompts)
  --purge   Also delete $MOD_DIR after restoring
  -h, --help  Show this help text
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yes) ASSUME_YES=1; shift ;;
        --purge) PURGE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

info()  { echo "→ $*"; }
ok()    { echo "✓ $*"; }
warn()  { echo "! $*"; }

echo "======================================"
echo " Vivaldi Swift — macOS Uninstaller"
echo "======================================"
echo

# ----------------------------------------------------------------------------
# 1. Locate Vivaldi.app
# ----------------------------------------------------------------------------
APP_PATH=""
for candidate in "/Applications/Vivaldi.app" "$HOME/Applications/Vivaldi.app"; do
    if [ -d "$candidate" ]; then
        APP_PATH="$candidate"
        break
    fi
done

if [ -z "$APP_PATH" ]; then
    warn "Vivaldi.app not found; skipping window.html restoration."
else
    vivaldi_dir="$APP_PATH/Contents/Resources/vivaldi"
    latest_backup="$(find "$MOD_DIR/backups/macos" -maxdepth 1 -name "window.html-*" 2>/dev/null | sort | tail -n 1)"

    SUDO=""
    [ -w "$vivaldi_dir" ] || SUDO="sudo"

    if [ -z "$latest_backup" ]; then
        warn "No backup found; removing injected tags manually instead."
        $SUDO sed -i '' \
            -e 's#<link rel="stylesheet" href="vivaldi_swift.css">##' \
            -e 's#<script src="custom.js"></script>##' \
            "$vivaldi_dir/window.html" 2>/dev/null || warn "Could not clean window.html"
    else
        info "Restoring window.html from $latest_backup"
        if $SUDO cp "$latest_backup" "$vivaldi_dir/window.html"; then
            ok "Restored $vivaldi_dir/window.html"
        else
            warn "Failed to restore window.html"
        fi
    fi

    $SUDO rm -f "$vivaldi_dir/vivaldi_swift.css" "$vivaldi_dir/custom.js" 2>/dev/null || true

    if command -v codesign >/dev/null 2>&1; then
        $SUDO codesign --force --deep --sign - "$APP_PATH" 2>/dev/null || \
            warn "Re-signing failed; run 'xattr -cr \"$APP_PATH\"' if macOS reports the app as damaged."
    fi
fi

# ----------------------------------------------------------------------------
# 2. Remove LaunchAgent
# ----------------------------------------------------------------------------
info "Removing LaunchAgent..."
launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
rm -f "$PLIST_PATH"
ok "LaunchAgent removed."

# ----------------------------------------------------------------------------
# 3. Optionally purge the install directory
# ----------------------------------------------------------------------------
if [ "$PURGE" -eq 1 ]; then
    if [ "$ASSUME_YES" -eq 0 ]; then
        read -rp "Delete $MOD_DIR entirely, including logs and backups? [y/N] " answer
        [[ "${answer,,}" == "y" ]] || { info "Skipping directory removal."; PURGE=0; }
    fi
    if [ "$PURGE" -eq 1 ]; then
        rm -rf "$MOD_DIR"
        ok "Removed $MOD_DIR"
    fi
else
    info "$MOD_DIR left in place (logs/backups preserved). Use --purge to remove it."
fi

echo
ok "Vivaldi Swift uninstalled. Restart Vivaldi to see the original UI."
