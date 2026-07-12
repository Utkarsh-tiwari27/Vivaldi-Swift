#!/usr/bin/env bash
#
# Vivaldi Swift — macOS Patch Engine
# ----------------------------------------------------------------------------
# Injects the Vivaldi Swift CSS and JS into a Vivaldi.app bundle's
# window.html, so the modifications load on every browser start.
#
# Supports:
#   - /Applications/Vivaldi.app                 (standard install)
#   - ~/Applications/Vivaldi.app                 (user-scope install)
#   - Homebrew cask installs (symlinked into /Applications by default,
#     also checked directly under the Homebrew Caskroom)
#   - Intel and Apple Silicon (no architecture-specific paths involved;
#     both ship the same Resources layout)
#
# Usage:
#   patch-macos.sh [--mod-dir <path>] [--app-path <path>] [--yes] [--quiet]
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
[ -f "$LIB_DIR/common.sh" ] || LIB_DIR="$SCRIPT_DIR/lib"   # installed layout: bin/patch-macos.sh, bin/lib/common.sh
# shellcheck source=SCRIPTDIR/../lib/common.sh
source "$LIB_DIR/common.sh"

DEFAULT_MOD_DIR="$HOME/Vivaldi-Swift"
MOD_DIR="$DEFAULT_MOD_DIR"
FORCED_APP_PATH=""
ASSUME_YES=0
QUIET=0

CSS_FILE="vivaldi_swift.css"
JS_FILE="custom.js"
CSS_MARKER='<link rel="stylesheet" href="vivaldi_swift.css">'
JS_MARKER='<script src="custom.js"></script>'

usage() {
    cat <<EOF
Vivaldi Swift — macOS Patch Engine

Usage: $(basename "$0") [options]

Options:
  --mod-dir <path>   Directory containing vivaldi_swift.css / custom.js
                      (default: $DEFAULT_MOD_DIR)
  --app-path <path>  Explicit path to Vivaldi.app, skips auto-detection
  --yes              Non-interactive mode; auto-selects when a single
                      installation is found, fails otherwise
  --quiet            Suppress console output (log file still written)
  -h, --help         Show this help text
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --mod-dir)
            MOD_DIR="${2:-}"
            [ -z "$MOD_DIR" ] && { echo "Missing value for --mod-dir" >&2; exit 1; }
            shift 2
            ;;
        --app-path)
            FORCED_APP_PATH="${2:-}"
            [ -z "$FORCED_APP_PATH" ] && { echo "Missing value for --app-path" >&2; exit 1; }
            shift 2
            ;;
        --yes) ASSUME_YES=1; shift ;;
        --quiet) QUIET=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

LOG_FILE="$MOD_DIR/logs/patch-macos.log"

log INFO "=== patch-macos.sh started (mod-dir=$MOD_DIR) ==="

# ----------------------------------------------------------------------------
# Locate candidate Vivaldi.app bundles
# ----------------------------------------------------------------------------
find_installs() {
    local -a candidates=(
        "/Applications/Vivaldi.app"
        "$HOME/Applications/Vivaldi.app"
    )

    # Homebrew Caskroom (in case the /Applications symlink is missing)
    if command -v brew >/dev/null 2>&1; then
        local brew_prefix
        brew_prefix="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
        if [ -d "$brew_prefix/Caskroom/vivaldi" ]; then
            while IFS= read -r d; do
                candidates+=("$d")
            done < <(find "$brew_prefix/Caskroom/vivaldi" -maxdepth 2 -name "Vivaldi.app" 2>/dev/null)
        fi
    fi

    local -a found=()
    for c in "${candidates[@]}"; do
        [ -d "$c" ] && found+=("$c")
    done

    printf '%s\n' "${found[@]}"
}

if [ -n "$FORCED_APP_PATH" ]; then
    app_path="$FORCED_APP_PATH"
else
    mapfile -t app_candidates < <(find_installs)

    if [ "${#app_candidates[@]}" -eq 0 ]; then
        log ERROR "No Vivaldi.app found in /Applications, ~/Applications, or Homebrew Caskroom."
        exit 1
    fi

    if [ "${#app_candidates[@]}" -eq 1 ]; then
        selected=0
        log INFO "Single Vivaldi installation detected: ${app_candidates[0]}"
    elif [ "$ASSUME_YES" -eq 1 ]; then
        log ERROR "Multiple installations found and --yes was given; specify --app-path explicitly."
        printf '%s\n' "${app_candidates[@]}" >&2
        exit 1
    else
        echo "---------------------"
        echo "Vivaldi installations found:"
        for i in "${!app_candidates[@]}"; do
            printf '%d) %s\n' "$((i + 1))" "${app_candidates[$i]}"
        done
        echo
        read -rp "Select installation number (X to cancel): " answer

        [[ "${answer^^}" == "X" ]] && { log INFO "User cancelled selection."; exit 0; }

        if ! [[ "$answer" =~ ^[0-9]+$ ]]; then
            log ERROR "Invalid selection: $answer"
            exit 1
        fi

        selected=$((answer - 1))
        if (( selected < 0 || selected >= ${#app_candidates[@]} )); then
            log ERROR "Selection out of range: $answer"
            exit 1
        fi
    fi

    app_path="${app_candidates[$selected]}"
fi

vivaldi_dir="$app_path/Contents/Resources/vivaldi"

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
if [ -f "$app_path/Contents/Info.plist" ]; then
    vivaldi_version="$(defaults read "$app_path/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)"
fi
log INFO "Detected Vivaldi version: $vivaldi_version"

# ----------------------------------------------------------------------------
# Determine whether elevated privileges are required
# ----------------------------------------------------------------------------
SUDO="$(prime_sudo "$vivaldi_dir")"

# ----------------------------------------------------------------------------
# Locate the most recent backup on disk (used both for rollback and as a
# fallback when this run doesn't create a fresh one).
# ----------------------------------------------------------------------------
backup_subdir="$MOD_DIR/backups/macos"

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
        sed -i '' "s#</body>#${CSS_MARKER}</body>#" "$tmp_file"
    fi
    if ! grep -qF "$JS_MARKER" "$tmp_file"; then
        sed -i '' "s#</body>#${JS_MARKER}</body>#" "$tmp_file"
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

# Re-sign the app bundle so macOS Gatekeeper does not flag the modified
# bundle as damaged. Ad-hoc signing is sufficient for local use.
if command -v codesign >/dev/null 2>&1; then
    log INFO "Re-signing Vivaldi.app (ad-hoc) after modification"
    $SUDO codesign --force --deep --sign - "$app_path" 2>>"$LOG_FILE" || \
        log WARN "codesign failed; Vivaldi may show a 'damaged app' warning on next launch. If so, run: xattr -cr '$app_path'"
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
log INFO "=== patch-macos.sh finished ==="
