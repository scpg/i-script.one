#!/usr/bin/env bash
# is1-description: Verify is1 installation — checks PATH, symlinks, and tools

set -euo pipefail

_LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/is1-lib.sh"
# shellcheck source=../lib/is1-lib.sh
source "$_LIB"

_BIN="${HOME}/.local/bin"
_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
_REPO="$(cd "$(dirname "$_SELF")/../../" && pwd)"
_issues=0

_usage() {
    printf 'Usage: %s [-h]\n\n' "$(basename "$0")"
    printf 'Verify the is1 installation. Exits 0 for pass/warn, 1 for errors.\n'
}

while getopts "h" _opt; do
    case "$_opt" in
        h) _usage; exit 0 ;;
        *) _usage >&2; exit 1 ;;
    esac
done

_pass() { printf '%s[PASS]%s %s\n' "$_GRN" "$_RST" "$*"; }
_fail() { printf '%s[FAIL]%s %s\n' "$_RED" "$_RST" "$*" >&2; (( _issues++ )) || true; }
_note() { printf '%s[WARN]%s %s\n' "$_YEL" "$_RST" "$*"; }

step "Checking is1 installation"

# ── 1. PATH ────────────────────────────────────────────────────────────────────
if printf ':%s:' "$PATH" | grep -q ":${_BIN}:"; then
    _pass "$_BIN is in PATH"
else
    _fail "$_BIN is NOT in PATH — commands will not be found"
    printf '   Add to ~/.bashrc or ~/.zshrc:\n'
    # shellcheck disable=SC2016
    printf '       export PATH="%s:$PATH"\n' "$_BIN"
fi

# ── 2. git ────────────────────────────────────────────────────────────────────
if command -v git >/dev/null 2>&1; then
    _pass "git found: $(git --version)"
else
    _fail "git not found — required for is1-update"
fi

# ── 3. shellcheck ─────────────────────────────────────────────────────────────
if command -v shellcheck >/dev/null 2>&1 && shellcheck --version >/dev/null 2>&1; then
    _scver="$(shellcheck --version 2>/dev/null | grep -m1 'version:' | awk '{print $2}')" || true
    _pass "shellcheck found${_scver:+: $_scver}"
else
    _note "shellcheck not found — is1-bash-syntax-check will fall back to bash -n"
    printf '   Install: apt install shellcheck\n'
fi

# ── 4. Symlinks for all repo scripts ──────────────────────────────────────────
step "Checking symlinks"

# Collect expected links from repo
_expected=()
while IFS= read -r -d '' _script; do
    _expected+=("$(basename "$_script" .sh)")
done < <(find "$_REPO/sh" -name "is1-*.sh" \
    -not -path "$_REPO/sh/is1/*" \
    -not -path "$_REPO/sh/lib/*" \
    -print0 | sort -z)
for _meta in is1 is1-install is1-update is1-remove is1-doctor; do
    [ -f "$_REPO/sh/is1/${_meta}.sh" ] && _expected+=("$_meta")
done

for _name in "${_expected[@]}"; do
    _link="$_BIN/$_name"
    if [ -L "$_link" ]; then
        _target="$(readlink -f "$_link" 2>/dev/null || true)"
        if [ -x "$_target" ]; then
            _pass "$_name → $_target"
        else
            _fail "$_name → target not executable: $_target"
        fi
    else
        _fail "$_name — symlink missing in $_BIN (run: is1-install)"
    fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
printf '\n'
if [ "$_issues" -eq 0 ]; then
    step "All checks passed"
else
    step "$_issues issue(s) found"
    exit 1
fi
