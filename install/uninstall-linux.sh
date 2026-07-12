#!/usr/bin/env bash
#
# Vivaldi Swift — Linux Uninstaller
# ----------------------------------------------------------------------------
# Restores the most recent window.html backup for each detected Vivaldi
# installation, removes the auto-update service, and optionally deletes
# the ~/Vivaldi-Swift directory.
#
# Usage:
#   ./uninstall-linux.sh [--yes] [--purge]
# ----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
[ -f "$LIB_DIR/common.sh" ] || LIB_DIR="$SCRIPT_DIR"   # installed layout: bin/uninstall-linux.sh, bin/lib/common.sh
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$LIB_DIR/common.sh"

MOD_DIR="$HOME/Vivaldi-Swift"
ASSUME_YES=0
PURGE=0

usage() {
    cat <<EOF
Vivaldi Swift — Linux Uninstaller

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

banner "Vivaldi Swift — Linux Uninstaller"

# ----------------------------------------------------------------------------
# 1. Restore window.html from the newest backup, for every install found
# ----------------------------------------------------------------------------
mapfile -t vivaldi_install_dirs < <(
    find /opt -maxdepth 3 -type f \
    \( -name "vivaldi-bin" -o -name "vivaldi-snapshot-bin" \) \
    -exec dirname {} \; 2>/dev/null | sort -u
)

if [ "${#vivaldi_install_dirs[@]}" -eq 0 ]; then
    warn "No Vivaldi installation found under /opt. Skipping window.html restoration."
else
    for dir in "${vivaldi_install_dirs[@]}"; do
        vivaldi_dir="$dir/resources/vivaldi"
        [ -d "$vivaldi_dir" ] || continue

        latest_backup="$(find "$MOD_DIR/backups/linux" -maxdepth 1 -name "window.html-*" 2>/dev/null | sort | tail -n 1)"

        SUDO=""
        [ -w "$vivaldi_dir" ] || SUDO="sudo"

        if [ -z "$latest_backup" ]; then
            warn "No backup found for $vivaldi_dir; removing injected tags manually instead."
            $SUDO sed -i \
                -e 's#<link rel="stylesheet" href="vivaldi_swift.css">##' \
                -e 's#<script src="custom.js"></script>##' \
                "$vivaldi_dir/window.html" 2>/dev/null || warn "Could not clean window.html at $vivaldi_dir"
        else
            step "Restoring window.html for $vivaldi_dir from $latest_backup"
            if $SUDO cp "$latest_backup" "$vivaldi_dir/window.html"; then
                ok "Restored $vivaldi_dir/window.html"
            else
                warn "Failed to restore window.html for $vivaldi_dir"
            fi
        fi

        $SUDO rm -f "$vivaldi_dir/vivaldi_swift.css" "$vivaldi_dir/custom.js" 2>/dev/null || true
    done
fi

# ----------------------------------------------------------------------------
# 2. Remove the auto-update service
# ----------------------------------------------------------------------------
step "Removing auto-update service..."

if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now vivaldi-swift.timer >/dev/null 2>&1 || true
    rm -f "$HOME/.config/systemd/user/vivaldi-swift.service" "$HOME/.config/systemd/user/vivaldi-swift.timer"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

if command -v crontab >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -vF "$MOD_DIR/bin/update-linux.sh" | grep -vF "$MOD_DIR/bin/patch-linux.sh" | crontab - 2>/dev/null || true
fi

ok "Auto-update service removed."

# ----------------------------------------------------------------------------
# 3. Optionally purge the install directory
# ----------------------------------------------------------------------------
if [ "$PURGE" -eq 1 ]; then
    if [ "$ASSUME_YES" -eq 0 ]; then
        read -rp "Delete $MOD_DIR entirely, including logs and backups? [y/N] " answer
        [[ "${answer,,}" == "y" ]] || { step "Skipping directory removal."; PURGE=0; }
    fi
    if [ "$PURGE" -eq 1 ]; then
        rm -rf "$MOD_DIR"
        ok "Removed $MOD_DIR"
    fi
else
    step "$MOD_DIR left in place (logs/backups preserved). Use --purge to remove it."
fi

echo
ok "Vivaldi Swift uninstalled. Restart Vivaldi to see the original UI."
