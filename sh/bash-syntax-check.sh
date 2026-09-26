#!/usr/bin/env bash
# Run bash -n on one or more scripts and report results.
# Usage: bash-syntax-check.sh <script> [<script> ...]

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

if [[ $# -eq 0 ]]; then
    echo "Usage: $(basename "$0") <script> [<script> ...]"
    exit 1
fi

errors=0
for f in "$@"; do
    if bash -n "$f" 2>&1; then
        echo -e "${GREEN}OK${NC}  $f"
    else
        echo -e "${RED}FAIL${NC} $f"
        (( errors++ )) || true
    fi
done

exit $errors
