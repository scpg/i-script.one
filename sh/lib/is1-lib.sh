#!/usr/bin/env bash
# is1-lib.sh — shared helpers for all is1 scripts
# Source with:
#   LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/is1-lib.sh"
#   source "$LIB"
#
# Guards against double-sourcing:
[ -n "${_IS1_LIB_LOADED:-}" ] && return 0
_IS1_LIB_LOADED=1

# ── Dry-run / quiet control ───────────────────────────────────────────────────
IS1_DRY_RUN="${IS1_DRY_RUN:-0}"
IS1_QUIET="${IS1_QUIET:-0}"

# ── Output / colors ───────────────────────────────────────────────────────────
# Uses tput when available and stdout is a tty; falls back to plain output
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    _RED="$(tput setaf 1)"
    _YEL="$(tput setaf 3)"
    _GRN="$(tput setaf 2)"
    _CYA="$(tput setaf 6)"
    _BLD="$(tput bold)"
    _RST="$(tput sgr0)"
else
    _RED=''; _YEL=''; _GRN=''; _CYA=''; _BLD=''; _RST=''
fi

info()  { [ "${IS1_QUIET:-0}" = "1" ] && return 0; printf '%s[INFO]%s  %s\n'  "$_GRN" "$_RST" "$*"; }
warn()  { printf '%s[WARN]%s  %s\n'  "$_YEL" "$_RST" "$*" >&2; }
error() { printf '%s[ERROR]%s %s\n'  "$_RED" "$_RST" "$*" >&2; }
die()   { error "$*"; exit 1; }
step()  { [ "${IS1_QUIET:-0}" = "1" ] && return 0; printf '%s==>%s %s%s%s\n' "$_CYA" "$_RST" "$_BLD" "$*" "$_RST"; }

# ── Input / validation ────────────────────────────────────────────────────────
# require_arg NAME VALUE — dies if VALUE is empty
require_arg() { [ -n "${2:-}" ] || die "Missing required argument: $1"; }

# require_file PATH — dies if file doesn't exist
require_file() { [ -f "$1" ] || die "Required file not found: $1"; }

# require_dir PATH — dies if directory doesn't exist
require_dir() { [ -d "$1" ] || die "Required directory not found: $1"; }

# ── Standard flag convention ──────────────────────────────────────────────────
# All is1 scripts accept these flags via getopts. Use this snippet in each script:
#
#   while getopts "hnq" _opt; do
#     case "$_opt" in
#       h) usage; exit 0 ;;
#       n) IS1_DRY_RUN=1 ;;
#       q) IS1_QUIET=1 ;;
#       *) usage >&2; exit 1 ;;
#     esac
#   done
#   shift $((OPTIND - 1))

# ── Tool availability ────────────────────────────────────────────────────────
# tool_available CMD — returns 0 if CMD can actually be executed.
# Checks both: (1) CMD is in PATH, and (2) CMD --version exits successfully.
# This correctly returns false for shims/wrappers that are in PATH but fail
# because no version is configured, or for binaries with bad permissions.
tool_available() {
    command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1
}

# ── Command execution ─────────────────────────────────────────────────────────
# run CMD [ARGS…] — execute or print (dry-run mode)
run() {
    if [ "$IS1_DRY_RUN" = "1" ]; then
        printf '%s[DRY-RUN]%s %s\n' "$_YEL" "$_RST" "$*"
    else
        "$@"
    fi
}

# ── Privilege helpers ─────────────────────────────────────────────────────────
require_sudo() {
    [ "$(id -u)" -eq 0 ] && return 0
    if ! sudo -n true 2>/dev/null; then
        info "This script requires sudo. You may be prompted for your password."
    fi
    sudo -v || die "sudo access required"
}

# ── OS detection (Linux + macOS) ──────────────────────────────────────────────
# Returns: ubuntu, debian, fedora, … on Linux; macos on macOS; lowercased uname otherwise
detect_os() {
    local _os
    _os="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    case "$_os" in
        linux)
            if [ -f /etc/os-release ]; then
                # shellcheck source=/dev/null
                . /etc/os-release
                printf '%s' "${ID:-linux}"
            else
                printf 'linux'
            fi
            ;;
        darwin) printf 'macos' ;;
        *)      printf '%s' "$_os" ;;
    esac
}

detect_os_version() {
    case "$(uname -s 2>/dev/null)" in
        Linux)
            if [ -f /etc/os-release ]; then
                # shellcheck source=/dev/null
                . /etc/os-release
                printf '%s' "${VERSION_ID:-unknown}"
            else
                printf 'unknown'
            fi
            ;;
        Darwin) sw_vers -productVersion 2>/dev/null || printf 'unknown' ;;
        *)      printf 'unknown' ;;
    esac
}

# ── Syslog helper ─────────────────────────────────────────────────────────────
# syslog_msg TAG MESSAGE — writes to syslog; fails silently if logger unavailable
syslog_msg() {
    local _tag="$1"; shift
    logger -t "$_tag" "$*" 2>/dev/null || true
}
