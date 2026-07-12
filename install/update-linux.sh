#!/usr/bin/env bash
#
# Vivaldi Swift — Linux Updater
# ----------------------------------------------------------------------------
# Updates an existing Vivaldi Swift install in place, without a manual ZIP
# download: fetches the latest GitHub Release, replaces the CSS/JS/patch
# engine, and reapplies the patch. User icons, logs, and backups are left
# untouched.
#
# Usage:
#   ./update-linux.sh [--yes]
#
# Exit codes:
#   0  success (updated, or already up to date)
#   1  not installed / not found
#   2  download or extraction failed
#   3  patch reapplication failed
# ----------------------------------------------------------------------------

set -euo pipefail

# Placeholder org/repo — matches the rest of the project until it's
# published under its real GitHub location.
REPO="vivaldi-swift/vivaldi-swift"
RELEASE_BASE="https://github.com/$REPO/releases/latest/download"

MOD_DIR="$HOME/Vivaldi-Swift"
ASSUME_YES=0

usage() {
    cat <<EOF
Vivaldi Swift — Linux Updater

Usage: $(basename "$0") [options]

Options:
  --yes       Non-interactive mode (auto-confirm all prompts)
  -h, --help  Show this help text
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yes) ASSUME_YES=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

info()  { echo "  $*"; }
ok()    { echo "✓ $*"; }
warn()  { echo "! $*"; }
fail()  { echo "✗ $*" >&2; exit 1; }

echo "──────────────────────────────"
echo " Vivaldi Swift Updater"
echo "──────────────────────────────"

if [ ! -d "$MOD_DIR" ]; then
    fail "Vivaldi Swift is not installed ($MOD_DIR not found). Run install-linux.sh first."
fi

command -v curl  >/dev/null 2>&1 || fail "curl is required to check for updates."
command -v unzip >/dev/null 2>&1 || fail "unzip is required to install updates."

# ----------------------------------------------------------------------------
# Compare local vs. remote version.json — no need to download the full
# release archive just to find out an update isn't needed.
# ----------------------------------------------------------------------------
local_version="unknown"
[ -f "$MOD_DIR/version.json" ] && \
    local_version="$(grep -oP '"version"\s*:\s*"\K[^"]+' "$MOD_DIR/version.json" 2>/dev/null || echo unknown)"

remote_version_json="$(mktemp)"
work_dir="$(mktemp -d)"
cleanup() { rm -f "$remote_version_json"; rm -rf "$work_dir"; }
trap cleanup EXIT

if ! curl -fsSL -o "$remote_version_json" "$RELEASE_BASE/version.json"; then
    fail "Could not reach GitHub Releases for $REPO. Check your connection and the REPO placeholder in this script."
fi
remote_version="$(grep -oP '"version"\s*:\s*"\K[^"]+' "$remote_version_json" 2>/dev/null || echo unknown)"

info "Installed version : $local_version"
info "Latest version     : $remote_version"

if [ "$local_version" = "$remote_version" ] && [ "$remote_version" != "unknown" ]; then
    ok "Already up to date (v$local_version)."
    exit 0
fi

# ----------------------------------------------------------------------------
# Download and extract the latest release
# ----------------------------------------------------------------------------
archive="$work_dir/vivaldi-swift.zip"
info "Downloading latest release..."
if ! curl -fsSL -o "$archive" "$RELEASE_BASE/vivaldi-swift.zip"; then
    fail "Download failed. Check your connection and the REPO placeholder in this script."
fi

if ! unzip -q "$archive" -d "$work_dir/extracted"; then
    fail "Could not extract the downloaded release archive."
fi

# The release zip may contain a single top-level folder; find the repo root
# by locating version.json inside it.
new_root="$(dirname "$(find "$work_dir/extracted" -maxdepth 3 -name "version.json" | head -n 1)")"
if [ -z "$new_root" ] || [ ! -d "$new_root" ]; then
    fail "Downloaded release archive has an unexpected layout."
fi
ok "Downloaded and extracted v$remote_version"

# ----------------------------------------------------------------------------
# Replace only the files Vivaldi Swift owns. Icons, logs, backups, and any
# local overrides (*.local.css/js) are never touched.
# ----------------------------------------------------------------------------
info "Updating CSS, JS, and patch engine..."

cp -f "$new_root/css/vivaldi_swift.css" "$MOD_DIR/vivaldi_swift.css"
cp -f "$new_root/js/custom.js" "$MOD_DIR/custom.js"

mkdir -p "$MOD_DIR/bin"
cp -f "$new_root/install/patch/patch-linux.sh" "$MOD_DIR/bin/patch-linux.sh"
chmod +x "$MOD_DIR/bin/patch-linux.sh"
[ -f "$new_root/install/uninstall-linux.sh" ] && {
    cp -f "$new_root/install/uninstall-linux.sh" "$MOD_DIR/bin/uninstall-linux.sh"
    chmod +x "$MOD_DIR/bin/uninstall-linux.sh"
}
[ -f "$new_root/install/update-linux.sh" ] && {
    cp -f "$new_root/install/update-linux.sh" "$MOD_DIR/bin/update-linux.sh"
    chmod +x "$MOD_DIR/bin/update-linux.sh"
}
[ -f "$new_root/version.json" ] && cp -f "$new_root/version.json" "$MOD_DIR/version.json"

ok "Files updated."

# ----------------------------------------------------------------------------
# Reapply the patch with the freshly-updated files
# ----------------------------------------------------------------------------
info "Reapplying patch..."
PATCH_ARGS=("--mod-dir" "$MOD_DIR" "--yes")
if ! "$MOD_DIR/bin/patch-linux.sh" "${PATCH_ARGS[@]}"; then
    fail "Patch reapplication failed. See $MOD_DIR/logs/patch-linux.log for details."
fi

echo
ok "Updated to v$remote_version. Restart Vivaldi to see the changes."
