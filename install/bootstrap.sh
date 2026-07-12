#!/usr/bin/env bash
#
# Vivaldi Swift — Bootstrap Installer (Linux + macOS)
# ----------------------------------------------------------------------------
# Lets a first-time user install Vivaldi Swift with a single command,
# without cloning the repository by hand:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/Utkarsh-tiwari27/Vivaldi-Swift/main/install/bootstrap.sh)
#
# Vivaldi Swift has no releases or version numbers — the repository itself
# is the source of truth. This script downloads the current snapshot of
# the main branch, extracts it, runs the matching platform installer
# (install-linux.sh or install-macos.sh), and cleans up after itself. Any
# arguments given to this script are passed straight through to the
# platform installer, e.g. `--yes` or `--no-auto-patch`.
# ----------------------------------------------------------------------------

set -euo pipefail

REPO="Utkarsh-tiwari27/Vivaldi-Swift"
SNAPSHOT_URL="https://codeload.github.com/$REPO/zip/refs/heads/main"

info()  { echo "  $*"; }
ok()    { echo "✓ $*"; }
fail()  { echo "✗ $*" >&2; exit 1; }

echo "──────────────────────────────"
echo " Vivaldi Swift Installer"
echo "──────────────────────────────"

case "$(uname -s)" in
    Linux)  PLATFORM="linux" ;;
    Darwin) PLATFORM="macos" ;;
    *) fail "Unsupported operating system: $(uname -s). Vivaldi Swift supports Linux and macOS here — see the Windows instructions for PowerShell." ;;
esac
ok "Detecting operating system"
info "$PLATFORM"

command -v curl  >/dev/null 2>&1 || fail "curl is required to install Vivaldi Swift."
command -v unzip >/dev/null 2>&1 || fail "unzip is required to install Vivaldi Swift."

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

archive="$work_dir/vivaldi-swift.zip"
info "Downloading the latest repository snapshot..."
if ! curl -fsSL -o "$archive" "$SNAPSHOT_URL"; then
    fail "Download failed. Check your connection and that $REPO exists and has a main branch."
fi
ok "Downloaded latest snapshot"

if ! unzip -q "$archive" -d "$work_dir/extracted"; then
    fail "Could not extract the downloaded snapshot archive."
fi

installer="$(find "$work_dir/extracted" -maxdepth 3 -name "install-$PLATFORM.sh" | head -n 1)"
if [ -z "$installer" ]; then
    fail "Could not find install-$PLATFORM.sh in the downloaded snapshot. The repository layout may have changed."
fi
chmod +x "$installer"

echo "──────────────────────────────"
"$installer" "$@"
