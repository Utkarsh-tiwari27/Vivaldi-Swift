#!/usr/bin/env bash
#
# Vivaldi Swift — Shared Shell Library
# ----------------------------------------------------------------------------
# Sourced by every Linux/macOS install, update, patch, and uninstall script.
# Centralizes: terminal output, logging, sudo handling, and repository
# snapshot syncing. Keeping this logic in one place is what lets each
# platform script stay focused on the parts that actually differ.
#
# This file is not meant to be executed directly.
# ----------------------------------------------------------------------------

VIVALDI_SWIFT_REPO="Utkarsh-tiwari27/Vivaldi-Swift"
VIVALDI_SWIFT_BRANCH="main"
VIVALDI_SWIFT_CODELOAD_URL="https://codeload.github.com/${VIVALDI_SWIFT_REPO}/zip/refs/heads/${VIVALDI_SWIFT_BRANCH}"
VIVALDI_SWIFT_API_COMMIT_URL="https://api.github.com/repos/${VIVALDI_SWIFT_REPO}/commits/${VIVALDI_SWIFT_BRANCH}"

# ----------------------------------------------------------------------------
# Terminal output
# ----------------------------------------------------------------------------
# Color support: only when writing to a real terminal that isn't "dumb"
# and the user hasn't opted out via NO_COLOR (https://no-color.org/).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
    C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
    C_GREEN=""; C_RED=""; C_YELLOW=""; C_DIM=""; C_BOLD=""; C_RESET=""
fi

HR="──────────────────────────────"

banner() {
    echo "$HR"
    echo " ${C_BOLD}$*${C_RESET}"
    echo "$HR"
}

step()  { echo "  $*"; }
ok()    { echo "${C_GREEN}✓${C_RESET} $*"; }
warn()  { echo "${C_YELLOW}!${C_RESET} $*"; }
fail()  { echo "${C_RED}✗${C_RESET} $*" >&2; exit 1; }
dim()   { echo "${C_DIM}$*${C_RESET}"; }

# ----------------------------------------------------------------------------
# Structured logging. Callers set LOG_FILE and QUIET before sourcing calls
# to log(); mkdir -p on the log directory happens automatically.
# ----------------------------------------------------------------------------
log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    if [ -n "${LOG_FILE:-}" ]; then
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        echo "[$ts] [$level] $msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
    if [ "${QUIET:-0}" -eq 0 ]; then
        case "$level" in
            ERROR) echo "${C_RED}✗${C_RESET} $msg" >&2 ;;
            WARN)  echo "${C_YELLOW}!${C_RESET} $msg" ;;
            OK)    echo "${C_GREEN}✓${C_RESET} $msg" ;;
            *)     echo "  $msg" ;;
        esac
    fi
}

# ----------------------------------------------------------------------------
# Privilege handling — prime sudo once up front so the rest of the install
# runs without repeated password prompts. No-op if we already have write
# access to the target, or sudo isn't needed/available.
# ----------------------------------------------------------------------------
prime_sudo() {
    local target="$1"
    [ -w "$target" ] && { echo ""; return; }
    command -v sudo >/dev/null 2>&1 || { fail "No write permission to $target and sudo is unavailable."; }
    sudo -v || fail "Could not obtain administrator privileges."
    # Keep the sudo timestamp alive for the lifetime of this script.
    ( while true; do sudo -n true 2>/dev/null; sleep 60; done ) &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true' EXIT
    echo "sudo"
}

# ----------------------------------------------------------------------------
# Repository state — Vivaldi Swift has no version numbers or releases.
# The repository itself is the source of truth: "changed" simply means
# "the latest commit on main has a different SHA than the one we last
# synced." This is the one lightweight network call the background
# updater makes when it isn't already due for a full sync.
# ----------------------------------------------------------------------------
remote_repo_sha() {
    curl -fsSL -H "Accept: application/vnd.github+json" "$VIVALDI_SWIFT_API_COMMIT_URL" 2>/dev/null \
        | grep -m1 '"sha"' \
        | sed -E 's/.*"sha"[[:space:]]*:[[:space:]]*"([0-9a-f]+)".*/\1/'
}

local_repo_sha() {
    local state_file="$1"
    if [ -f "$state_file" ]; then
        cat "$state_file" 2>/dev/null
    fi
}

# Downloads and extracts the current main-branch snapshot into $1 (a
# directory that must already exist). Echoes the path to the extracted
# repository root on success.
download_repo_snapshot() {
    local dest_dir="$1"
    local archive="$dest_dir/vivaldi-swift.zip"

    curl -fsSL -o "$archive" "$VIVALDI_SWIFT_CODELOAD_URL" || return 1
    unzip -q "$archive" -d "$dest_dir/extracted" || return 1

    find "$dest_dir/extracted" -maxdepth 1 -mindepth 1 -type d | head -n 1
}
