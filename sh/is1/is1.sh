#!/usr/bin/env bash
# is1-description: i-script-one — list and dispatch available is1 commands
# Usage: is1 [<command> [args…]] | is1 help

set -euo pipefail

_LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/is1-lib.sh"
# shellcheck source=../lib/is1-lib.sh
source "$_LIB"

_usage() {
    printf 'Usage: is1 [command] [args…]\n\n'
    printf 'Available commands:\n\n'
    # Find all is1-* commands reachable in PATH, print name + description
    while IFS= read -r _cmd; do
        _name="${_cmd##*/}"
        # Look for: # is1-description: <text> (anywhere in first 10 lines)
        _desc="$(head -10 "$(command -v "$_name" 2>/dev/null || true)" 2>/dev/null \
            | grep '^# is1-description:' \
            | sed 's/^# is1-description:[[:space:]]*//' \
            || true)"
        [ -z "$_desc" ] && _desc="(no description)"
        printf '  %-36s %s\n' "$_name" "$_desc"
    done < <(compgen -c 'is1-' 2>/dev/null | sort -u)
    printf '\nRun any command directly, or: is1 <command> [args…]\n'
}

# No args or explicit help → show list
if [ $# -eq 0 ] || [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    _usage
    exit 0
fi

# Dispatch to is1-<command>
_cmd="is1-$1"; shift
if ! command -v "$_cmd" >/dev/null 2>&1; then
    error "Unknown command: $_cmd"
    printf '\nRun '\''is1 help'\'' to see available commands.\n' >&2
    exit 1
fi
exec "$_cmd" "$@"
