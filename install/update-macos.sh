#!/usr/bin/env bash
#
# Vivaldi Swift — macOS Updater
# ----------------------------------------------------------------------------
# Updates an existing Vivaldi Swift install in place, without a manual ZIP
# download: fetches the latest GitHub Release, replaces the CSS/JS/patch
# engine, and reapplies the patch. User icons, logs, and backups are left
# untouched.
#
# Usage:
#   ./update-macos.sh [--yes] [--app-path <path>]
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
FORCED_APP_PATH=""

usage() {
    cat <<EOF
Vivaldi Swift — macOS Updater

Usage: $(basename "$0") [options]

Options:
  --yes                Non-interactive mode (auto-confirm all prompts)
  --app-path <path>    Explicit path to Vivaldi.app (passed through to the
                        patch engine when reapplying)
  -h, --help            Show this help text
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yes) ASSUME_YES=1; shift ;;
        --app-path)
            FORCED_APP_PATH="${2:-}"
            [ -z "$FORCED_APP_PATH" ] && { echo "Missing value for --app-path" >&2; exit 1; }
            shift 2
            ;;
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
    fail "Vivaldi Swift is not installed ($MOD_DIR not found). Run install-macos.sh first."
fi

command -v curl  >/dev/null 2>&1 || fail "curl is required to check for updates."
command -v unzip >/dev/null 2>&1 || fail "unzip is required to install updates."

# ----------------------------------------------------------------------------
# Compare local vs. remote version.json — no need to download the full
# release archive just to find out an update isn't needed.
# ----------------------------------------------------------------------------
local_version="unknown"
if [ -f "$MOD_DIR/version.json" ]; then
    local_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MOD_DIR/version.json" | head -n 1)"
    [ -z "$local_version" ] && local_version="unknown"
fi

remote_version_json="$(mktemp)"
work_dir="$(mktemp -d)"
cleanup() { rm -f "$remote_version_json"; rm -rf "$work_dir"; }
trap cleanup EXIT

if ! curl -fsSL -o "$remote_version_json" "$RELEASE_BASE/version.json"; then
    fail "Could not reach GitHub Releases for $REPO. Check your connection and the REPO placeholder in this script."
fi
remote_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$remote_version_json" | head -n 1)"
[ -z "$remote_version" ] && remote_version="unknown"

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
cp -f "$new_root/install/patch/patch-macos.sh" "$MOD_DIR/bin/patch-macos.sh"
chmod +x "$MOD_DIR/bin/patch-macos.sh"
[ -f "$new_root/install/uninstall-macos.sh" ] && {
    cp -f "$new_root/install/uninstall-macos.sh" "$MOD_DIR/bin/uninstall-macos.sh"
    chmod +x "$MOD_DIR/bin/uninstall-macos.sh"
}
[ -f "$new_root/install/update-macos.sh" ] && {
    cp -f "$new_root/install/update-macos.sh" "$MOD_DIR/bin/update-macos.sh"
    chmod +x "$MOD_DIR/bin/update-macos.sh"
}
[ -f "$new_root/version.json" ] && cp -f "$new_root/version.json" "$MOD_DIR/version.json"

ok "Files updated."

# ----------------------------------------------------------------------------
# Reapply the patch with the freshly-updated files
# ----------------------------------------------------------------------------
info "Reapplying patch..."
PATCH_ARGS=("--mod-dir" "$MOD_DIR" "--yes")
[ -n "$FORCED_APP_PATH" ] && PATCH_ARGS+=("--app-path" "$FORCED_APP_PATH")

if ! "$MOD_DIR/bin/patch-macos.sh" "${PATCH_ARGS[@]}"; then
    fail "Patch reapplication failed. See $MOD_DIR/logs/patch-macos.log for details."
fi

echo
ok "Updated to v$remote_version. Restart Vivaldi to see the changes."
