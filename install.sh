#!/usr/bin/env bash
# Bootstrap: install all is1 commands to ~/.local/bin
set -euo pipefail
_REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
exec "$_REPO/sh/is1/is1-install.sh" "$@"
