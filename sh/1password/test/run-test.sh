#!/usr/bin/env bash
#
# Test harness for install-1password.sh.
#
# SAFETY: this script ONLY ever runs the installer inside a disposable Docker
# container. It never touches the host system. The container is removed after
# every run (--rm), so each test starts from a clean machine.
#
# Usage:
#   ./run-test.sh [FLAVOUR] [MODE] [-- EXTRA ARGS...]
#
#   FLAVOUR   Linux flavour to test. Default: ubuntu
#             (matches a subdirectory containing a Dockerfile, e.g. ubuntu/)
#   MODE      auto   Run the installer non-interactively (default)
#             shell  Drop into an interactive shell in the container
#
#   Anything after `--` is passed straight to install-1password.sh.
#
# Examples:
#   ./run-test.sh                       # auto-run installer on Ubuntu, verbose
#   ./run-test.sh ubuntu shell          # interactive shell to poke around
#   ./run-test.sh ubuntu auto -- --help # pass --help to the installer
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FLAVOUR="${1:-ubuntu}"
MODE="${2:-auto}"

# Collect installer args after a literal `--`.
INSTALLER_ARGS=(--verbose)
for ((i = 1; i <= $#; i++)); do
  if [[ "${!i}" == "--" ]]; then
    INSTALLER_ARGS=("${@:i+1}")
    break
  fi
done

DOCKERFILE="$SCRIPT_DIR/$FLAVOUR/Dockerfile"
IMAGE="1pw-test-$FLAVOUR"
# Build context is the script's own directory so the Dockerfile can COPY it.
CONTEXT="$SCRIPT_DIR/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker is not installed or not on PATH. This harness requires Docker." >&2
  exit 1
fi

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "❌ No Dockerfile for flavour '$FLAVOUR' (looked for $DOCKERFILE)." >&2
  echo "   Available flavours:" >&2
  find "$SCRIPT_DIR" -mindepth 2 -maxdepth 2 -name Dockerfile -printf '     - %h\n' \
    | sed "s#$SCRIPT_DIR/##" >&2
  exit 1
fi

echo "🐳 Building test image '$IMAGE' from $FLAVOUR/Dockerfile ..."
docker build -t "$IMAGE" -f "$DOCKERFILE" "$CONTEXT"

# Mount the live script over the baked-in copy so edits take effect without a
# rebuild. Read-only so the test can never modify your working tree.
MOUNT=(-v "$CONTEXT/install-1password.sh:/home/tester/install-1password.sh:ro")

if [[ "$MODE" == "shell" ]]; then
  echo "🐚 Launching interactive shell (user: tester, sudo password: test)."
  echo "   Run the installer with: ./install-1password.sh --verbose"
  exec docker run --rm -it "${MOUNT[@]}" "$IMAGE" bash
else
  echo "▶️  Running installer in container: install-1password.sh ${INSTALLER_ARGS[*]}"
  exec docker run --rm "${MOUNT[@]}" "$IMAGE" \
    bash -lc "./install-1password.sh ${INSTALLER_ARGS[*]}"
fi
