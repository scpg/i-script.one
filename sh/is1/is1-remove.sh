#!/usr/bin/env bash
# is1-description: Remove all is1 command symlinks from ~/.local/bin

set -euo pipefail

_LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/is1-lib.sh"
# shellcheck source=../lib/is1-lib.sh
source "$_LIB"

_BIN="${HOME}/.local/bin"
_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
_REPO="$(cd "$(dirname "$_SELF")/../../" && pwd)"
_FORCE=0

_usage() {
    printf 'Usage: %s [-h] [-n] [--force]\n\n' "$(basename "$0")"
    printf 'Remove all is1-* symlinks in %s that point into this repo.\n\n' "$_BIN"
    printf 'Options:\n'
    printf '  -h        show this help\n'
    printf '  -n        dry-run: print what would be removed, make no changes\n'
    printf '  --force   skip confirmation prompt\n'
}

# Parse args (getopts + manual --force)
_args=()
for _arg in "$@"; do
    case "$_arg" in
        --force) _FORCE=1 ;;
        *) _args+=("$_arg") ;;
    esac
done
set -- "${_args[@]+"${_args[@]}"}"

while getopts "hn" _opt; do
    case "$_opt" in
        h) _usage; exit 0 ;;
        n) IS1_DRY_RUN=1 ;;
        *) _usage >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# Find symlinks to remove
_to_remove=()
if [ -d "$_BIN" ]; then
    while IFS= read -r -d '' _link; do
        _target="$(readlink -f "$_link" 2>/dev/null || true)"
        # Only remove if target lives inside this repo
        if [[ "$_target" == "$_REPO"/* ]]; then
            _to_remove+=("$_link")
        fi
    done < <(find "$_BIN" -maxdepth 1 -name 'is1*' -type l -print0 2>/dev/null)
fi

if [ ${#_to_remove[@]} -eq 0 ]; then
    info "No is1 symlinks found in $_BIN"
    exit 0
fi

printf 'Will remove %d symlink(s):\n' "${#_to_remove[@]}"
for _link in "${_to_remove[@]}"; do
    printf '  %s\n' "$_link"
done

if [ "$IS1_DRY_RUN" = "1" ]; then
    printf '\n[DRY-RUN] No changes made.\n'
    exit 0
fi

if [ "$_FORCE" = "0" ]; then
    printf '\nProceed? [y/N] '
    read -r _answer
    case "$_answer" in
        [yY]*) ;;
        *) info "Aborted."; exit 0 ;;
    esac
fi

for _link in "${_to_remove[@]}"; do
    rm -f "$_link"
    info "Removed: $_link"
done
info "Done: ${#_to_remove[@]} symlinks removed"
