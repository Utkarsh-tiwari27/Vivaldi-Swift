#!/usr/bin/env bash
#
# Vivaldi Swift — Linux Installer
# ----------------------------------------------------------------------------
# Sets up ~/Vivaldi-Swift, copies the CSS/JS payload and patch engine into
# it, applies the patch to a detected Vivaldi installation, and installs a
# systemd user service (falling back to cron) that keeps the mod re-applied
# after Vivaldi auto-updates.
#
# Usage:
#   ./install-linux.sh [--yes] [--no-auto-patch]
# ----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MOD_DIR="$HOME/Vivaldi-Swift"
ASSUME_YES=0
INSTALL_AUTO_PATCH=1

usage() {
    cat <<EOF
Vivaldi Swift — Linux Installer

Usage: $(basename "$0") [options]

Options:
  --yes              Non-interactive mode (auto-confirm all prompts)
  --no-auto-patch     Skip installing the systemd/cron auto-reapply service
  -h, --help          Show this help text
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yes) ASSUME_YES=1; shift ;;
        --no-auto-patch) INSTALL_AUTO_PATCH=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

info()  { echo "  $*"; }
ok()    { echo "${C_GREEN}✓${C_RESET} $*"; }
warn()  { echo "${C_YELLOW}!${C_RESET} $*"; }
fail()  { echo "${C_RED}✗${C_RESET} $*" >&2; exit 1; }

# Color support: only when writing to a real terminal that isn't "dumb"
# and the user hasn't opted out via NO_COLOR (https://no-color.org/).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
    C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
    C_GREEN=""; C_RED=""; C_YELLOW=""; C_BOLD=""; C_RESET=""
fi

HR="──────────────────────────────"

echo "$HR"
echo " ${C_BOLD}Vivaldi Swift Installer${C_RESET}"
echo "$HR"

# ----------------------------------------------------------------------------
# 1. Detect distro (informational, used only for messaging/logging)
# ----------------------------------------------------------------------------
DISTRO="unknown"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    DISTRO="$(. /etc/os-release && echo "${PRETTY_NAME:-$ID}")"
fi
ok "Detecting operating system"
info "$DISTRO"

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
mkdir -p "$MOD_DIR"/{css,js,icons,backups,logs,bin}
ok "Creating directories"
info "$MOD_DIR"

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
[ -f "$REPO_ROOT/version.json" ] && cp -f "$REPO_ROOT/version.json" "$MOD_DIR/version.json"

# ----------------------------------------------------------------------------
# 5. Install the patch service: copy the patch engine into $MOD_DIR/bin and
#    register the background job that keeps it reapplied after Vivaldi
#    updates (systemd user timer, cron fallback).
# ----------------------------------------------------------------------------
cp -f "$SCRIPT_DIR/patch/patch-linux.sh" "$MOD_DIR/bin/patch-linux.sh"
chmod +x "$MOD_DIR/bin/patch-linux.sh"
cp -f "$SCRIPT_DIR/uninstall-linux.sh" "$MOD_DIR/bin/uninstall-linux.sh" 2>/dev/null || true
chmod +x "$MOD_DIR/bin/uninstall-linux.sh" 2>/dev/null || true
[ -f "$SCRIPT_DIR/update-linux.sh" ] && { cp -f "$SCRIPT_DIR/update-linux.sh" "$MOD_DIR/bin/update-linux.sh"; chmod +x "$MOD_DIR/bin/update-linux.sh"; }

if [ "$INSTALL_AUTO_PATCH" -eq 1 ]; then
    if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
        UNIT_DIR="$HOME/.config/systemd/user"
        mkdir -p "$UNIT_DIR"

        cat > "$UNIT_DIR/vivaldi-swift.service" <<EOF
[Unit]
Description=Vivaldi Swift patch reapplication

[Service]
Type=oneshot
ExecStart=$MOD_DIR/bin/patch-linux.sh --yes --quiet
EOF

        cat > "$UNIT_DIR/vivaldi-swift.timer" <<EOF
[Unit]
Description=Periodically reapply Vivaldi Swift after Vivaldi updates

[Timer]
OnBootSec=2min
OnUnitActiveSec=6h
Persistent=true

[Install]
WantedBy=timers.target
EOF

        systemctl --user daemon-reload
        systemctl --user enable --now vivaldi-swift.timer >/dev/null 2>&1 || \
            warn "Could not enable the systemd timer automatically. Run: systemctl --user enable --now vivaldi-swift.timer"

        ok "Installing patch service"
        info "systemd user timer (runs every 6h and at login)"
    elif command -v crontab >/dev/null 2>&1; then
        CRON_LINE="0 */6 * * * $MOD_DIR/bin/patch-linux.sh --yes --quiet"
        ( crontab -l 2>/dev/null | grep -vF "$MOD_DIR/bin/patch-linux.sh" ; echo "$CRON_LINE" ) | crontab -
        ok "Installing patch service"
        info "cron fallback (runs every 6h)"
    else
        ok "Installing patch service"
        warn "Neither systemd --user nor cron is available. Re-run $MOD_DIR/bin/patch-linux.sh manually after Vivaldi updates."
    fi
else
    ok "Installing patch service"
    info "auto-reapply skipped (--no-auto-patch)"
fi

# ----------------------------------------------------------------------------
# 6. Apply the patch (backs up window.html, injects CSS/JS, then verifies —
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
echo "To uninstall, run: install/uninstall-linux.sh"
