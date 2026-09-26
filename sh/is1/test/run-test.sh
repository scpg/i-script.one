#!/usr/bin/env bash
# Run the is1 meta-tool bats tests inside a disposable Docker container.
# MANDATORY: never run these tests on the host machine.
#
# Usage:
#   ./run-test.sh           # run all tests
#   ./run-test.sh shell     # interactive shell for debugging

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
_REPO="$(cd "$_SCRIPT_DIR/../../../" && pwd)"
_IMAGE="is1-test"

_build() {
    printf '==> Building test image...\n'
    docker build -q -t "$_IMAGE" "$_SCRIPT_DIR"
}

_run_tests() {
    docker run --rm \
        -v "$_REPO:/repo:ro" \
        -e HOME=/home/testuser \
        -u testuser \
        "$_IMAGE" \
        bats /repo/sh/is1/test/install.bats
}

_run_shell() {
    printf '==> Starting interactive shell (repo mounted at /repo)\n'
    docker run --rm -it \
        -v "$_REPO:/repo:ro" \
        -e HOME=/home/testuser \
        -u testuser \
        "$_IMAGE" \
        bash
}

_build

case "${1:-}" in
    shell) _run_shell ;;
    *)     _run_tests ;;
esac
