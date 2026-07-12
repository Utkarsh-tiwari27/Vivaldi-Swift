#!/usr/bin/env bash
#
# Vivaldi Swift — Linux Patch Engine
# ----------------------------------------------------------------------------
# Injects the Vivaldi Swift CSS and JS into a Vivaldi installation's
# window.html, so the modifications load on every browser start.
#
# This script is idempotent: running it multiple times will not create
# duplicate injections, and it is safe to call from the installer, from
# the auto-updater after a Vivaldi update, or manually.
#
# Usage:
#   patch-linux.sh [--mod-dir <path>] [--install-dir <path>] [--yes] [--quiet]
#
# Exit codes:
#   0  success (patched or already up to date)
#   1  Vivaldi not found
#   2  mod files missing
#   3  permission error
#   4  patch operation failed
# ----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
[ -f "$LIB_DIR/common.sh" ] || LIB_DIR="$SCRIPT_DIR/lib"   # installed layout: bin/patch-linux.sh, bin/lib/common.sh
# shellcheck source=SCRIPTDIR/../lib/common.sh
source "$LIB_DIR/common.sh"

DEFAULT_MOD_DIR="$HOME/Vivaldi-Swift"
MOD_DIR="$DEFAULT_MOD_DIR"
FORCED_INSTALL_DIR=""
ASSUME_YES=0
QUIET=0

CSS_FILE="vivaldi_swift.css"
JS_FILE="custom.js"
CSS_MARKER='<link rel="stylesheet" href="vivaldi_swift.css">'
JS_MARKER='<script src="custom.js"></script>'

usage() {
    cat <<EOF
Vivaldi Swift — Linux Patch Engine

Usage: $(basename "$0") [options]

Options:
  --mod-dir <path>       Directory containing vivaldi_swift.css / custom.js
                          (default: $DEFAULT_MOD_DIR)
  --install-dir <path>   Explicit Vivaldi resources/vivaldi directory,
                          skips auto-detection and the selection prompt
  --yes                  Non-interactive mode; auto-selects when a single
                          installation is found, fails otherwise
  --quiet                Suppress console output (log file still written)
  -h, --help             Show this help text
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --mod-dir)
            MOD_DIR="${2:-}"
            [ -z "$MOD_DIR" ] && { echo "Missing value for --mod-dir" >&2; exit 1; }
            shift 2
            ;;
        --install-dir)
            FORCED_INSTALL_DIR="${2:-}"
            [ -z "$FORCED_INSTALL_DIR" ] && { echo "Missing value for --install-dir" >&2; exit 1; }
            shift 2
            ;;
        --yes) ASSUME_YES=1; shift ;;
        --quiet) QUIET=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

LOG_FILE="$MOD_DIR/logs/patch-linux.log"

log INFO "=== patch-linux.sh started (mod-dir=$MOD_DIR) ==="

# ----------------------------------------------------------------------------
# Locate candidate Vivaldi installations
# ----------------------------------------------------------------------------
find_installs() {
    local -a dirs=()

    # Standard /opt layout (stable + snapshot), official .deb/.rpm packages
    if [ -d /opt ]; then
        while IFS= read -r d; do
            dirs+=("$d")
        done < <(find /opt -maxdepth 3 -type f \
                  \( -name "vivaldi-bin" -o -name "vivaldi-snapshot-bin" \) \
                  -exec dirname {} \; 2>/dev/null | sort -u)
    fi

    # Snap installs expose the binary tree under /snap/vivaldi/current
    if [ -d /snap/vivaldi/current/opt ]; then
        while IFS= read -r d; do
            dirs+=("$d")
        done < <(find /snap/vivaldi/current/opt -maxdepth 3 -type f \
                  -name "vivaldi-bin" -exec dirname {} \; 2>/dev/null)
    fi

    printf '%s\n' "${dirs[@]}"
}

resolve_vivaldi_dir() {
    local install_dir="$1"
    echo "$install_dir/resources/vivaldi"
}

# ----------------------------------------------------------------------------
# Select installation
# ----------------------------------------------------------------------------
if [ -n "$FORCED_INSTALL_DIR" ]; then
    vivaldi_dir="$FORCED_INSTALL_DIR"
else
    mapfile -t vivaldi_install_dirs < <(find_installs)

    if [ "${#vivaldi_install_dirs[@]}" -eq 0 ]; then
        log ERROR "No Vivaldi installation found under /opt or /snap."
        exit 1
    fi

    if [ "${#vivaldi_install_dirs[@]}" -eq 1 ]; then
        selected=0
        log INFO "Single Vivaldi installation detected: ${vivaldi_install_dirs[0]}"
    elif [ "$ASSUME_YES" -eq 1 ]; then
        log ERROR "Multiple installations found and --yes was given; specify --install-dir explicitly."
        printf '%s\n' "${vivaldi_install_dirs[@]}" >&2
        exit 1
    else
        echo "---------------------"
        echo "Vivaldi installations found:"
        for i in "${!vivaldi_install_dirs[@]}"; do
            printf '%d) %s\n' "$((i + 1))" "${vivaldi_install_dirs[$i]}"
        done
        echo
        read -rp "Select installation number (X to cancel): " answer

        [[ "${answer^^}" == "X" ]] && { log INFO "User cancelled selection."; exit 0; }

        if ! [[ "$answer" =~ ^[0-9]+$ ]]; then
            log ERROR "Invalid selection: $answer"
            exit 1
        fi

        selected=$((answer - 1))
        if (( selected < 0 || selected >= ${#vivaldi_install_dirs[@]} )); then
            log ERROR "Selection out of range: $answer"
            exit 1
        fi
    fi

    vivaldi_dir="$(resolve_vivaldi_dir "${vivaldi_install_dirs[$selected]}")"
fi

log INFO "Mod directory : $MOD_DIR"
log INFO "Target        : $vivaldi_dir"

# ----------------------------------------------------------------------------
# Verify required files
# ----------------------------------------------------------------------------
if [ ! -f "$vivaldi_dir/window.html" ]; then
    log ERROR "window.html not found at $vivaldi_dir"
    exit 1
fi

if [ ! -f "$MOD_DIR/$JS_FILE" ]; then
    log ERROR "custom.js missing: $MOD_DIR/$JS_FILE (run the installer first)"
    exit 2
fi

if [ ! -f "$MOD_DIR/$CSS_FILE" ]; then
    log ERROR "vivaldi_swift.css missing: $MOD_DIR/$CSS_FILE (run the installer first)"
    exit 2
fi

# ----------------------------------------------------------------------------
# Detect Vivaldi version for logging
# ----------------------------------------------------------------------------
vivaldi_version="unknown"
if [ -f "$vivaldi_dir/version.json" ]; then
    vivaldi_version="$(grep -oP '"version"\s*:\s*"\K[^"]+' "$vivaldi_dir/version.json" 2>/dev/null || echo unknown)"
fi
log INFO "Detected Vivaldi version: $vivaldi_version"

# ----------------------------------------------------------------------------
# Determine whether a privilege escalation helper is required
# ----------------------------------------------------------------------------
SUDO="$(prime_sudo "$vivaldi_dir")"

# ----------------------------------------------------------------------------
# Locate the most recent backup on disk (used both for rollback and as a
# fallback when this run doesn't create a fresh one).
# ----------------------------------------------------------------------------
backup_subdir="$MOD_DIR/backups/linux"

latest_backup() {
    find "$backup_subdir" -maxdepth 1 -name "window.html-*" 2>/dev/null | sort | tail -n 1
}

# ----------------------------------------------------------------------------
# Restore window.html from a backup and explain what happened. Used whenever
# post-patch verification fails, so a bad patch never sticks around.
# ----------------------------------------------------------------------------
rollback() {
    local reason="$1"
    local restore_from
    restore_from="${backup_path:-$(latest_backup)}"

    log ERROR "Verification failed: $reason"

    if [ -n "$restore_from" ] && [ -f "$restore_from" ]; then
        if $SUDO cp "$restore_from" "$vivaldi_dir/window.html"; then
            log OK "Backup restored from $restore_from — Vivaldi is back to its previous state."
        else
            log ERROR "Automatic restore also failed. Manually restore with:"
            log ERROR "  sudo cp \"$restore_from\" \"$vivaldi_dir/window.html\""
        fi
    else
        log ERROR "No backup was available to restore. Please reinstall Vivaldi or restore window.html manually."
    fi

    log ERROR "Vivaldi Swift was not applied. See $LOG_FILE for details."
    exit 4
}

# ----------------------------------------------------------------------------
# Already patched? (idempotency check)
# ----------------------------------------------------------------------------
already_patched=0
if grep -qF "$JS_MARKER" "$vivaldi_dir/window.html" 2>/dev/null && \
   grep -qF "$CSS_MARKER" "$vivaldi_dir/window.html" 2>/dev/null
then
    already_patched=1
fi

backup_path=""

if [ "$already_patched" -eq 1 ]; then
    log OK "window.html already patched. Refreshing asset copies only."
else
    mkdir -p "$backup_subdir"
    timestamp="$(date +%Y-%m-%dT%H-%M-%S)"
    backup_path="$backup_subdir/window.html-$timestamp"

    log INFO "Creating backup at $backup_path"
    if ! $SUDO cp "$vivaldi_dir/window.html" "$backup_path"; then
        log ERROR "Failed to create backup. Aborting before touching window.html."
        exit 4
    fi
    if [ ! -s "$backup_path" ]; then
        log ERROR "Backup at $backup_path is missing or empty. Aborting before touching window.html."
        exit 4
    fi
    log OK "Creating backup"

    log INFO "Injecting CSS and JS references into window.html"

    tmp_file="$(mktemp)"
    cp "$vivaldi_dir/window.html" "$tmp_file"

    if ! grep -qF "$CSS_MARKER" "$tmp_file"; then
        sed -i "s#</body>#${CSS_MARKER}</body>#" "$tmp_file"
    fi
    if ! grep -qF "$JS_MARKER" "$tmp_file"; then
        sed -i "s#</body>#${JS_MARKER}</body>#" "$tmp_file"
    fi

    if ! $SUDO cp "$tmp_file" "$vivaldi_dir/window.html"; then
        rm -f "$tmp_file"
        rollback "could not write patched window.html"
    fi
    rm -f "$tmp_file"

    log OK "window.html patched successfully."
fi

# ----------------------------------------------------------------------------
# Copy CSS + JS payloads into the Vivaldi resource directory
# ----------------------------------------------------------------------------
log INFO "Copying $CSS_FILE and $JS_FILE into $vivaldi_dir"

if ! $SUDO cp -f "$MOD_DIR/$CSS_FILE" "$vivaldi_dir/$CSS_FILE"; then
    rollback "could not copy $CSS_FILE into place"
fi

if ! $SUDO cp -f "$MOD_DIR/$JS_FILE" "$vivaldi_dir/$JS_FILE"; then
    rollback "could not copy $JS_FILE into place"
fi

# ----------------------------------------------------------------------------
# Verify the patch actually took before declaring success. This is what
# lets the installer's "Verifying installation" step mean something.
# ----------------------------------------------------------------------------
log INFO "Verifying CSS and JS were successfully injected"

if ! grep -qF "$CSS_MARKER" "$vivaldi_dir/window.html" 2>/dev/null; then
    rollback "CSS reference is missing from window.html"
fi
if ! grep -qF "$JS_MARKER" "$vivaldi_dir/window.html" 2>/dev/null; then
    rollback "JS reference is missing from window.html"
fi
if [ ! -s "$vivaldi_dir/$CSS_FILE" ]; then
    rollback "$CSS_FILE is missing or empty at $vivaldi_dir"
fi
if [ ! -s "$vivaldi_dir/$JS_FILE" ]; then
    rollback "$JS_FILE is missing or empty at $vivaldi_dir"
fi

log OK "Verifying installation"

log OK "Vivaldi Swift patch applied (Vivaldi $vivaldi_version)."
log INFO "=== patch-linux.sh finished ==="
