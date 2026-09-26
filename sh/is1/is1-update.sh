#!/usr/bin/env bash
# is1-description: Pull latest changes from git and re-link all is1 commands

set -euo pipefail

_LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/is1-lib.sh"
# shellcheck source=../../lib/is1-lib.sh
source "$_LIB"

_usage() {
    printf 'Usage: %s [-h] [-n]\n\n' "$(basename "$0")"
    printf 'Pull the latest is1 repo changes and re-link all commands.\n\n'
    printf 'Options:\n'
    printf '  -h   show this help\n'
    printf '  -n   dry-run: print what would be done, make no changes\n'
}

while getopts "hn" _opt; do
    case "$_opt" in
        h) _usage; exit 0 ;;
        n) IS1_DRY_RUN=1 ;;
        *) _usage >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# Locate repo via BASH_SOURCE through symlink
_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
_REPO="$(cd "$(dirname "$_SELF")/../../" && pwd)"

if ! git -C "$_REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Not a git repo: $_REPO"
fi

step "Pulling latest changes"
run git -C "$_REPO" pull --ff-only

step "Re-linking commands"
run "$_REPO/sh/is1/is1-install.sh" -q

info "Update complete"
