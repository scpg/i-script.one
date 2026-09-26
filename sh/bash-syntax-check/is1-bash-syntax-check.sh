#!/usr/bin/env bash
# is1-description: Check bash syntax (shellcheck when available, bash -n otherwise)
# Usage: is1-bash-syntax-check <script> [<script> ...]

set -euo pipefail

_LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/is1-lib.sh"
# shellcheck source=../../lib/is1-lib.sh
source "$_LIB"

if [[ $# -eq 0 ]]; then
    printf 'Usage: %s <script> [<script> ...]\n' "$(basename "$0")" >&2
    exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
    _checker="shellcheck"
else
    warn "shellcheck not found — falling back to bash -n (weaker checking)"
    warn "Install shellcheck for SC2-level analysis: apt install shellcheck"
    _checker="bash_n"
fi

_errors=0
for _f in "$@"; do
    if [ "$_checker" = "shellcheck" ]; then
        if shellcheck "$_f"; then
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
