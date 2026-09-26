#!/usr/bin/env bash
# is1-description: Install is1 scripts as commands in ~/.local/bin via symlinks

set -euo pipefail

_LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/is1-lib.sh"
# shellcheck source=../../lib/is1-lib.sh
source "$_LIB"

_REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../" && pwd)"
_BIN="${HOME}/.local/bin"

_usage() {
    printf 'Usage: %s [-h] [-n] [-q]\n\n' "$(basename "$0")"
    printf 'Install all is1-* scripts as commands in %s.\n\n' "$_BIN"
    printf 'Options:\n'
    printf '  -h   show this help\n'
    printf '  -n   dry-run: print what would be done, make no changes\n'
    printf '  -q   quiet: suppress informational output\n'
}

while getopts "hnq" _opt; do
    case "$_opt" in
        h) _usage; exit 0 ;;
        n) IS1_DRY_RUN=1 ;;
        q) IS1_QUIET=1 ;;
        *) _usage >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

step "Installing is1 scripts → $_BIN"

# Create bin dir if needed
if [ ! -d "$_BIN" ]; then
    run mkdir -p "$_BIN"
    info "Created $_BIN"
fi

_linked=0

# ── Discover and link user scripts (is1-* under sh/, excluding sh/is1/ and sh/lib/) ──
while IFS= read -r -d '' _script; do
    _name="$(basename "$_script" .sh)"
    run chmod +x "$_script"
    run ln -sfn "$_script" "$_BIN/$_name"
    info "Linked: $_BIN/$_name"
    (( _linked++ )) || true
done < <(find "$_REPO/sh" -name "is1-*.sh" \
    -not -path "$_REPO/sh/is1/*" \
    -not -path "$_REPO/sh/lib/*" \
    -print0 | sort -z)

# ── Link meta-tools ───────────────────────────────────────────────────────────
for _meta in is1 is1-install is1-update is1-remove is1-doctor; do
    _src="$_REPO/sh/is1/${_meta}.sh"
    [ -f "$_src" ] || continue
    run chmod +x "$_src"
    run ln -sfn "$_src" "$_BIN/$_meta"
    info "Linked: $_BIN/$_meta"
    (( _linked++ )) || true
done

info "Done: $_linked commands linked"

# ── PATH check ────────────────────────────────────────────────────────────────
if printf ':%s:' "$PATH" | grep -q ":${_BIN}:"; then
    info "$_BIN is in PATH"
else
    _rc="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && _rc="$HOME/.zshrc"
    warn "$_BIN is not in PATH"
    printf '\n   Add to %s:\n' "$_rc"
    printf '       export PATH="%s:$PATH"\n' "$_BIN"
    printf '\n   Then reload:  source %s\n\n' "$_rc"
fi
