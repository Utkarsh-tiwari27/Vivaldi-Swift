#!/usr/bin/env bash
#
# Vivaldi Swift — Linux Installer
# ----------------------------------------------------------------------------
# Sets up ~/Vivaldi-Swift, copies the CSS/JS payload and patch engine into
# it, applies the patch to a detected Vivaldi installation, and installs a
# systemd user timer (cron fallback) that keeps Vivaldi Swift patched and
# quietly up to date on its own — no manual update command required.
#
# Usage:
#   ./install-linux.sh [--yes] [--no-auto-patch]
# ----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

MOD_DIR="$HOME/Vivaldi-Swift"
ASSUME_YES=0
INSTALL_AUTO_UPDATE=1

usage() {
    cat <<EOF
Vivaldi Swift — Linux Installer

Usage: $(basename "$0") [options]

Options:
  --yes              Non-interactive mode (auto-confirm all prompts)
  --no-auto-patch     Skip installing the systemd/cron auto-update service
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
# 1. Detect distro (informational, used only for messaging/logging)
# ----------------------------------------------------------------------------
DISTRO="unknown"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    DISTRO="$(. /etc/os-release && echo "${PRETTY_NAME:-$ID}")"
fi
ok "Detecting operating system"
step "$DISTRO"

# ----------------------------------------------------------------------------
# 2. Detect Vivaldi
# ----------------------------------------------------------------------------
VIVALDI_FOUND=0
if [ -d /opt ] && find /opt -maxdepth 3 -type f \
    \( -name "vivaldi-bin" -o -name "vivaldi-snapshot-bin" \) 2>/dev/null | grep -q .; then
    VIVALDI_FOUND=1
fi
if [ -d /snap/vivaldi ]; then
    VIVALDI_FOUND=1
fi

if [ "$VIVALDI_FOUND" -eq 0 ]; then
    fail "Vivaldi was not found under /opt or /snap. Install Vivaldi first: https://vivaldi.com/download/"
fi
ok "Detecting Vivaldi installation"

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
cp -f "$SCRIPT_DIR/patch/patch-linux.sh" "$MOD_DIR/bin/patch-linux.sh"
cp -f "$SCRIPT_DIR/update-linux.sh" "$MOD_DIR/bin/update-linux.sh"
cp -f "$SCRIPT_DIR/uninstall-linux.sh" "$MOD_DIR/bin/uninstall-linux.sh"
chmod +x "$MOD_DIR/bin/patch-linux.sh" "$MOD_DIR/bin/update-linux.sh" "$MOD_DIR/bin/uninstall-linux.sh"

if sha="$(remote_repo_sha)" && [ -n "$sha" ]; then
    echo "$sha" > "$MOD_DIR/.repo-sha"
fi

# ----------------------------------------------------------------------------
# 6. Register the background auto-update service. It reapplies the patch
#    and quietly syncs new repository changes on its own — there is no
#    manual update command.
# ----------------------------------------------------------------------------
if [ "$INSTALL_AUTO_UPDATE" -eq 1 ]; then
    if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
        UNIT_DIR="$HOME/.config/systemd/user"
        mkdir -p "$UNIT_DIR"

        cat > "$UNIT_DIR/vivaldi-swift.service" <<EOF
[Unit]
Description=Vivaldi Swift automatic update and patch reapplication

[Service]
Type=oneshot
ExecStart=$MOD_DIR/bin/update-linux.sh --quiet
EOF

        cat > "$UNIT_DIR/vivaldi-swift.timer" <<EOF
[Unit]
Description=Daily Vivaldi Swift update check (also catches up at login if overdue)

[Timer]
OnBootSec=2min
OnUnitActiveSec=24h
Persistent=true

[Install]
WantedBy=timers.target
EOF

        systemctl --user daemon-reload
        systemctl --user enable --now vivaldi-swift.timer >/dev/null 2>&1 || \
            warn "Could not enable the systemd timer automatically. Run: systemctl --user enable --now vivaldi-swift.timer"

        ok "Installing auto-update service"
        step "systemd user timer (runs daily, catches up at login if overdue)"
    elif command -v crontab >/dev/null 2>&1; then
        CRON_LINE="@reboot sleep 120 && $MOD_DIR/bin/update-linux.sh --quiet"
        CRON_LINE_DAILY="0 9 * * * $MOD_DIR/bin/update-linux.sh --quiet"
        ( crontab -l 2>/dev/null | grep -vF "$MOD_DIR/bin/update-linux.sh" ; echo "$CRON_LINE" ; echo "$CRON_LINE_DAILY" ) | crontab -
        ok "Installing auto-update service"
        step "cron fallback (runs daily and at boot)"
    else
        ok "Installing auto-update service"
        warn "Neither systemd --user nor cron is available. Vivaldi Swift will not update itself; re-run $MOD_DIR/bin/update-linux.sh manually to check for changes."
    fi
else
    ok "Installing auto-update service"
    step "auto-update skipped (--no-auto-patch)"
fi

# ----------------------------------------------------------------------------
# 7. Apply the patch (backs up window.html, injects CSS/JS, then verifies —
#    automatically rolling back if verification fails)
# ----------------------------------------------------------------------------
PATCH_ARGS=("--mod-dir" "$MOD_DIR")
[ "$ASSUME_YES" -eq 1 ] && PATCH_ARGS+=("--yes")

if ! "$MOD_DIR/bin/patch-linux.sh" "${PATCH_ARGS[@]}"; then
    fail "Patch failed. See $MOD_DIR/logs/patch-linux.log for details."
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
echo "Vivaldi Swift updates itself automatically — nothing else to run."
echo "To uninstall, run: install/uninstall-linux.sh"
