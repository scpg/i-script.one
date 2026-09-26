#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025 SCPG - 1386818+scpg@users.noreply.github.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# ─── DISCLAIMER ────────────────────────────────────────────────────────────────
# This script has been tested on a single device running Ubuntu 26.04. It has
# not undergone broad or systematic testing. It may not work correctly on your
# system. Use it at your own risk and review it before running on any machine
# you care about.
# ───────────────────────────────────────────────────────────────────────────────
#
# If this script saved you time, consider buying me a coffee:
# https://buymeacoffee.com/scpg.dev

set -euo pipefail
set -E                    # ERR trap inherited by functions
shopt -s inherit_errexit  # $() subshells also respect set -e (bash >= 4.4)

# ─── argument parsing ──────────────────────────────────────────────────────────

usage() {
    echo "Usage: $(basename "$0") [-n] [-h]"
    echo ""
    echo "  -n  Dry run — print what would be done without making any changes"
    echo "  -h  Show this help message"
    exit 0
}

DRY_RUN=false
while getopts ":nh" opt; do
    case "$opt" in
        n) DRY_RUN=true ;;
        h) usage ;;
        ?) echo "Unknown option: -$OPTARG" >&2; usage ;;
    esac
done
shift $((OPTIND - 1))

# ─── logging & helpers ─────────────────────────────────────────────────────────

LOG_TAG="docker-desktop-uninstall"
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

info()  {
    echo -e "${GREEN}[INFO]${NC}  $*"
    logger -t "$LOG_TAG" --id=$$ -p user.info   "INFO:  $*"
}
warn()  {
    echo -e "${YELLOW}[WARN]${NC}  $*"
    logger -t "$LOG_TAG" --id=$$ -p user.notice  "WARN:  $*"
}
error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    logger -t "$LOG_TAG" --id=$$ -p user.err    "ERROR: $*"
    exit 1
}

run() {
    if $DRY_RUN; then
        echo -e "${CYAN}[DRY-RUN]${NC} $*"
        logger -t "$LOG_TAG" --id=$$ -p user.notice "DRY-RUN: $*"
    else
        "$@"
    fi
}

confirm() {
    local prompt="$1"
    if $DRY_RUN; then
        warn "[DRY-RUN] Would prompt: $prompt"
        return 0
    fi
    read -r -p "$(echo -e "${YELLOW}[CONFIRM]${NC} $prompt [y/N] ")" response
    [[ "${response,,}" == "y" ]]
}

# ─── temp directory & traps ────────────────────────────────────────────────────

WORK_DIR=""

cleanup() {
    [[ -n "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
}

err_report() {
    local line="$1"
    echo -e "${RED}[ERROR]${NC} Unexpected error — call stack:" >&2
    local i
    for (( i=0; i<${#FUNCNAME[@]}-1; i++ )); do
        echo -e "${RED}[ERROR]${NC}   ${FUNCNAME[$i]} called from ${BASH_SOURCE[$i+1]}:${BASH_LINENO[$i]}" >&2
    done
    logger -t "$LOG_TAG" --id=$$ -p user.err "ERROR: unexpected error at line $line (${FUNCNAME[1]:-main})"
}

trap cleanup              EXIT
trap 'err_report $LINENO' ERR

WORK_DIR=$(mktemp -d)

# ─── checks ────────────────────────────────────────────────────────────────────

require_sudo() {
    if [[ $EUID -eq 0 ]]; then
        error "Do not run this script as root. Run as a normal user with sudo privileges."
    fi
    if ! sudo -n true 2>/dev/null; then
        info "This script requires sudo. You may be prompted for your password."
        sudo true || error "Unable to obtain sudo privileges."
    fi
}

check_apt_lock() {
    local lock=/var/lib/dpkg/lock-frontend
    local timeout=60 elapsed=0
    while sudo fuser "$lock" &>/dev/null 2>&1; do
        if [[ $elapsed -eq 0 ]]; then
            local holder cmd
            holder=$(sudo fuser "$lock" 2>/dev/null | tr -d ' ')
            cmd=$(ps -p "$holder" -o comm= 2>/dev/null || echo "unknown")
            warn "apt/dpkg lock is held by process $holder ($cmd) — waiting up to ${timeout}s..."
        fi
        if [[ $elapsed -ge $timeout ]]; then
            error "apt/dpkg lock not released after ${timeout}s. Check process: $(sudo fuser "$lock" 2>/dev/null). Re-run when apt is idle."
        fi
        sleep 5
        elapsed=$(( elapsed + 5 ))
    done
    if [[ $elapsed -gt 0 ]]; then info "apt/dpkg lock released ✓"; fi
}

# ─── preflight ────────────────────────────────────────────────────────────────
# All read-only checks run here before any change is made to the system.

preflight() {
    info "Running preflight checks..."

    require_sudo
    check_apt_lock

    # ── verify docker-desktop is installed ────────────────────────────────────
    if ! dpkg -l docker-desktop 2>/dev/null | grep -q '^ii'; then
        warn "Docker Desktop does not appear to be installed. Nothing to remove."
        exit 0
    fi
    local version
    version=$(dpkg -l docker-desktop | awk '/^ii/{print $3}')
    info "Found Docker Desktop $version — will be removed."

    # ── warn about running state ──────────────────────────────────────────────
    if systemctl --user is-active --quiet docker-desktop 2>/dev/null; then
        warn "Docker Desktop is currently running — it will be stopped before removal."
    fi

    # ── list user data directories that may be removed ────────────────────────
    local user_dirs=(
        "$HOME/.docker/desktop"
        "$HOME/.config/Docker Desktop"
        "$HOME/.local/share/Docker Desktop"
        "$HOME/.local/share/docker-desktop"
    )
    local found_dirs=()
    for d in "${user_dirs[@]}"; do
        [[ -e "$d" ]] && found_dirs+=("$d")
    done
    if [[ ${#found_dirs[@]} -gt 0 ]]; then
        warn "User data directories present (removal will be confirmed separately):"
        for d in "${found_dirs[@]}"; do warn "  $d"; done
    fi

    # ── check for docker context ──────────────────────────────────────────────
    if command -v docker &>/dev/null; then
        if docker context ls --format '{{.Name}}' 2>/dev/null | grep -q '^desktop-linux$'; then
            warn "Docker context 'desktop-linux' is present — will be removed."
        fi
    fi

    info "Preflight checks passed ✓"
}

# ─── stop docker desktop ───────────────────────────────────────────────────────

stop_docker_desktop() {
    if systemctl --user is-active --quiet docker-desktop 2>/dev/null; then
        info "Stopping Docker Desktop..."
        run systemctl --user stop docker-desktop
    else
        info "Docker Desktop is not running ✓"
    fi
    run systemctl --user disable docker-desktop 2>/dev/null || true
}

# ─── remove package ────────────────────────────────────────────────────────────

remove_package() {
    info "Removing docker-desktop package..."
    run sudo apt-get purge -y docker-desktop
    run sudo apt-get autoremove -y
    info "docker-desktop package removed ✓"
}

# ─── remove user configuration & data ─────────────────────────────────────────

remove_user_data() {
    local user_dirs=(
        "$HOME/.docker/desktop"
        "$HOME/.config/Docker Desktop"
        "$HOME/.local/share/Docker Desktop"
        "$HOME/.local/share/docker-desktop"
    )
    local systemd_units=(
        "$HOME/.config/systemd/user/docker-desktop.service"
        "$HOME/.config/systemd/user/default.target.wants/docker-desktop.service"
    )

    local existing_dirs=()
    for d in "${user_dirs[@]}"; do
        [[ -e "$d" ]] && existing_dirs+=("$d")
    done

    local existing_units=()
    for u in "${systemd_units[@]}"; do
        [[ -e "$u" ]] && existing_units+=("$u")
    done

    if [[ ${#existing_dirs[@]} -eq 0 && ${#existing_units[@]} -eq 0 ]]; then
        info "No Docker Desktop user data or systemd units found ✓"
        return
    fi

    warn "The following user-level files and directories will be removed:"
    for d in "${existing_dirs[@]}";  do warn "  $d"; done
    for u in "${existing_units[@]}"; do warn "  $u"; done

    if confirm "Remove Docker Desktop user configuration and data?"; then
        for d in "${existing_dirs[@]}";  do run rm -rf "$d";  done
        for u in "${existing_units[@]}"; do run rm -f  "$u";  done
        if ! $DRY_RUN; then
            systemctl --user daemon-reload 2>/dev/null || true
        else
            info "[DRY-RUN] Would reload systemd user daemon"
        fi
        info "User data removed ✓"
    else
        info "Skipping user data removal — files left intact."
    fi
}

# ─── remove docker context left by Desktop ─────────────────────────────────────

remove_docker_context() {
    if $DRY_RUN; then
        info "[DRY-RUN] Would remove 'desktop-linux' docker context if present"
        return
    fi
    if command -v docker &>/dev/null; then
        if docker context ls --format '{{.Name}}' 2>/dev/null | grep -q '^desktop-linux$'; then
            info "Removing 'desktop-linux' Docker context..."
            docker context rm desktop-linux 2>/dev/null || true
            info "Docker context removed ✓"
        else
            info "No 'desktop-linux' Docker context found ✓"
        fi
    fi
}

# ─── optionally remove repository config ───────────────────────────────────────

remove_repo_config() {
    local gpg_key="/etc/apt/keyrings/docker.asc"
    local sources_file="/etc/apt/sources.list.d/docker.sources"
    local found=false

    [[ -f "$gpg_key" ]]      && found=true
    [[ -f "$sources_file" ]] && found=true

    if ! $found; then
        info "No Docker repository config found ✓"
        return
    fi

    warn "Docker's apt repository config is still present (shared with Docker Engine)."
    if confirm "Also remove Docker apt repository configuration (GPG key + sources file)?"; then
        if [[ -f "$sources_file" ]]; then
            run sudo rm -f "$sources_file"
            info "Removed: $sources_file"
        fi
        if [[ -f "$gpg_key" ]]; then
            run sudo rm -f "$gpg_key"
            info "Removed: $gpg_key"
        fi
        run sudo apt-get update -qq
    else
        info "Skipping repository config removal — files left intact."
    fi
}

# ─── main ──────────────────────────────────────────────────────────────────────

main() {
    $DRY_RUN && warn "=== DRY-RUN MODE — no changes will be made ==="
    info "=== Docker Desktop for Ubuntu — full uninstall ==="

    preflight
    stop_docker_desktop
    remove_package
    remove_user_data
    remove_docker_context
    remove_repo_config

    info ""
    info "=== Uninstall complete ==="
}

main "$@"
