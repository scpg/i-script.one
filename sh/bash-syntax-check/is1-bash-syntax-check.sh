#!/usr/bin/env bash
# is1-description: Check bash syntax (shellcheck when available, bash -n otherwise)
# Usage: is1-bash-syntax-check <script> [<script> ...]

set -euo pipefail

_LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/is1-lib.sh"
# shellcheck source=../lib/is1-lib.sh
source "$_LIB"

if [[ $# -eq 0 ]]; then
    printf 'Usage: %s <script> [<script> ...]\n' "$(basename "$0")" >&2
    exit 1
fi

if tool_available shellcheck; then
    _checker="shellcheck"
elif command -v shellcheck >/dev/null 2>&1; then
    warn "shellcheck is in PATH but cannot run — check permissions or version manager configuration"
    warn "Falling back to bash -n (weaker checking)"
    _checker="bash_n"
else
    warn "shellcheck not installed — falling back to bash -n (weaker checking)"
    warn "Install: sudo apt install shellcheck  (or brew install shellcheck)"
    _checker="bash_n"
fi

_errors=0
for _f in "$@"; do
    if [ "$_checker" = "shellcheck" ]; then
        # cd to the script's directory so relative source= directives resolve correctly
        _dir="$(cd "$(dirname "$(readlink -f "$_f")")" && pwd)"
        if (cd "$_dir" && shellcheck -x "$_f"); then
            info "OK   $_f"
        else
            error "FAIL $_f"
            (( _errors++ )) || true
        fi
    else
        if bash -n "$_f" 2>&1; then
            info "OK   $_f"
        else
            error "FAIL $_f"
            (( _errors++ )) || true
        fi
    fi
done

exit "$_errors"
