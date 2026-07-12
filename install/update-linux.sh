#!/usr/bin/env bash
#
# Vivaldi Swift — Linux Auto-Updater
# ----------------------------------------------------------------------------
# This is the background service the installer registers with systemd (or
# cron). It is not meant to be run manually — install once, forget it
# exists. Whenever the repository changes, Vivaldi Swift quietly updates
# itself; there is no manual update command to run.
#
# The repository itself is the source of truth: no version numbers, no
# releases. "An update is available" simply means "the latest commit on
# main has a different SHA than the one we last synced."
#
# To keep this genuinely lightweight:
#   - A run started less than 24h after the last successful check exits
#     immediately without touching the network at all (self-gating; this
#     is what makes it safe to also trigger this script at login).
#   - If the repo hasn't changed, no snapshot is downloaded.
#   - The patch is re-verified locally on every run (free, no network) so
#     Vivaldi self-updates keep getting the UI reapplied even on days the
#     repository itself doesn't change.
#
# Usage:
#   ./update-linux.sh [--force] [--quiet]
#
# Exit codes:
#   0  success (up to date, updated, or skipped due to recent check)
#   1  not installed
#   2  download or extraction failed
#   3  patch reapplication failed
# ----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

MOD_DIR="$HOME/Vivaldi-Swift"
FORCE=0
QUIET=0
CHECK_INTERVAL_SECS=$((24 * 60 * 60))

usage() {
    cat <<EOF
Vivaldi Swift — Linux Auto-Updater

Usage: $(basename "$0") [options]

Options:
  --force     Bypass the 24h staleness gate and check now
  --quiet     Suppress console output (log file still written)
  -h, --help  Show this help text
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --force) FORCE=1; shift ;;
        --quiet) QUIET=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

LOG_FILE="$MOD_DIR/logs/update-linux.log"
STATE_FILE="$MOD_DIR/.repo-sha"
LAST_CHECK_FILE="$MOD_DIR/logs/.last-update-check"

log INFO "=== update-linux.sh started ==="

if [ ! -d "$MOD_DIR" ]; then
    log ERROR "Vivaldi Swift is not installed ($MOD_DIR not found)."
    exit 1
fi

# ----------------------------------------------------------------------------
# Staleness gate — avoids unnecessary network traffic when triggered both
# on a daily timer and at login.
# ----------------------------------------------------------------------------
if [ "$FORCE" -eq 0 ] && [ -f "$LAST_CHECK_FILE" ]; then
    last_check="$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo 0)"
    now="$(date +%s)"
    if [ -n "$last_check" ] && [ $((now - last_check)) -lt "$CHECK_INTERVAL_SECS" ]; then
        log INFO "Checked recently; skipping until the next scheduled run."
        exit 0
    fi
fi

command -v curl  >/dev/null 2>&1 || { log ERROR "curl is required to check for updates."; exit 2; }
command -v unzip >/dev/null 2>&1 || { log ERROR "unzip is required to install updates."; exit 2; }

# ----------------------------------------------------------------------------
# Compare the local and remote commit SHAs.
# ----------------------------------------------------------------------------
remote_sha="$(remote_repo_sha)"
if [ -z "$remote_sha" ]; then
    log WARN "Could not reach GitHub to check for updates. Will retry on the next run."
    exit 0
fi
date +%s > "$LAST_CHECK_FILE" 2>/dev/null || true

local_sha="$(local_repo_sha "$STATE_FILE")"

if [ "$remote_sha" = "$local_sha" ]; then
    log OK "Vivaldi Swift is up to date."
else
    log INFO "Repository has changed; syncing latest snapshot..."

    work_dir="$(mktemp -d)"
    trap 'rm -rf "$work_dir"' EXIT

    new_root="$(download_repo_snapshot "$work_dir")"
    if [ -z "$new_root" ] || [ ! -d "$new_root" ]; then
        log ERROR "Download or extraction failed."
        exit 2
    fi

    # Replace only the files Vivaldi Swift owns. Icons, logs, backups, and
    # any local overrides are never touched.
    cp -f "$new_root/css/vivaldi_swift.css" "$MOD_DIR/vivaldi_swift.css"
    cp -f "$new_root/js/custom.js" "$MOD_DIR/custom.js"

    mkdir -p "$MOD_DIR/bin" "$MOD_DIR/bin/lib"
    cp -f "$new_root/install/lib/common.sh" "$MOD_DIR/bin/lib/common.sh"
    cp -f "$new_root/install/patch/patch-linux.sh" "$MOD_DIR/bin/patch-linux.sh"
    cp -f "$new_root/install/update-linux.sh" "$MOD_DIR/bin/update-linux.sh"
    cp -f "$new_root/install/uninstall-linux.sh" "$MOD_DIR/bin/uninstall-linux.sh"
    chmod +x "$MOD_DIR/bin/patch-linux.sh" "$MOD_DIR/bin/update-linux.sh" "$MOD_DIR/bin/uninstall-linux.sh"

    echo "$remote_sha" > "$STATE_FILE"
    log OK "Repository synced to $remote_sha."
fi

# ----------------------------------------------------------------------------
# Reapply the patch unconditionally. This is a cheap, local, idempotent
# no-op if Vivaldi is already patched with the current files — it's what
# keeps the UI intact after Vivaldi itself auto-updates.
# ----------------------------------------------------------------------------
PATCH_ARGS=("--mod-dir" "$MOD_DIR" "--yes")
[ "$QUIET" -eq 1 ] && PATCH_ARGS+=("--quiet")

if ! "$MOD_DIR/bin/patch-linux.sh" "${PATCH_ARGS[@]}"; then
    log ERROR "Patch reapplication failed. See $MOD_DIR/logs/patch-linux.log for details."
    exit 3
fi

log INFO "=== update-linux.sh finished ==="
