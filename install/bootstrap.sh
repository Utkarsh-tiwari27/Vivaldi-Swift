#!/usr/bin/env bash
#
# Vivaldi Swift — Bootstrap Installer (Linux + macOS)
# ----------------------------------------------------------------------------
# Lets a first-time user install Vivaldi Swift with a single command,
# without cloning the repository or downloading a ZIP by hand:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/Utkarsh-tiwari27/Vivaldi-Swift/main/install/bootstrap.sh)
#
# It downloads the latest GitHub Release, extracts it, runs the matching
# platform installer (install-linux.sh or install-macos.sh), and cleans up
# after itself. Any arguments given to this script are passed straight
# through to the platform installer, e.g. `--yes` or `--no-auto-patch`.
# ----------------------------------------------------------------------------

set -euo pipefail

# Placeholder org/repo — matches the rest of the project until it's
# published under its real GitHub location.
REPO="Utkarsh-tiwari27/Vivaldi-Swift"
ARCHIVE_URL="https://github.com/$REPO/releases/latest/download/vivaldi-swift.zip"

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
info "Downloading the latest release..."
if ! curl -fsSL -o "$archive" "$ARCHIVE_URL"; then
    fail "Download failed. Check your connection and the REPO placeholder in this script."
fi
ok "Downloaded latest release"

if ! unzip -q "$archive" -d "$work_dir/extracted"; then
    fail "Could not extract the downloaded release archive."
fi

installer="$(find "$work_dir/extracted" -maxdepth 4 -name "install-$PLATFORM.sh" | head -n 1)"
if [ -z "$installer" ]; then
    fail "Could not find install-$PLATFORM.sh in the downloaded release. The release archive layout may have changed."
fi
chmod +x "$installer"

echo "──────────────────────────────"
"$installer" "$@"
