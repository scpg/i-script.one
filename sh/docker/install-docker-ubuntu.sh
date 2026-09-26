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

LOG_TAG="docker-install"
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

# ─── preflight checks ──────────────────────────────────────────────────────────

require_sudo() {
    if [[ $EUID -eq 0 ]]; then
        error "Do not run this script as root. Run as a normal user with sudo privileges."
    fi
    if ! sudo -n true 2>/dev/null; then
        info "This script requires sudo. You may be prompted for your password."
        sudo true || error "Unable to obtain sudo privileges."
    fi
}

check_architecture() {
    local arch
    arch=$(dpkg --print-architecture)
    local supported_archs=("amd64" "arm64" "armhf" "s390x" "ppc64le")
    local ok=false
    for a in "${supported_archs[@]}"; do
        [[ "$arch" == "$a" ]] && ok=true && break
    done
    if ! $ok; then
        error "Unsupported architecture: $arch. Docker Engine supports: ${supported_archs[*]}"
    fi
    info "Architecture: $arch ✓"
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        error "/etc/os-release not found. Cannot determine OS."
    fi
    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID:-}" != "ubuntu" ]]; then
        error "This script supports Ubuntu only. Detected ID=${ID:-unknown}. Derivative distros (e.g. Linux Mint) are not officially supported."
    fi

    local supported=("22.04" "24.04" "25.10" "26.04")
    local version="${VERSION_ID:-}"
    local ok=false
    for v in "${supported[@]}"; do
        [[ "$version" == "$v" ]] && ok=true && break
    done
    if ! $ok; then
        error "Unsupported Ubuntu version: $version. Supported: ${supported[*]}"
    fi
    info "OS: Ubuntu $version (${VERSION_CODENAME:-}) ✓"
}

check_firewall() {
    info "Checking firewall compatibility with Docker..."

    # ── iptables backend ─────────────────────────────────────────────────────
    # Docker requires iptables-nft or iptables-legacy. Pure nft rules are not supported.
    if command -v iptables &>/dev/null; then
        local iptables_ver
        iptables_ver=$(iptables --version 2>/dev/null || true)
        if echo "$iptables_ver" | grep -q '(nf_tables)'; then
            info "iptables backend: nf_tables (iptables-nft) ✓"
        elif echo "$iptables_ver" | grep -q '(legacy)'; then
            info "iptables backend: legacy ✓"
        else
            warn "Could not determine iptables backend from: $iptables_ver"
        fi
    else
        warn "iptables not found. Docker requires iptables-nft or iptables-legacy to be present."
    fi

    # ── pure nftables rules ───────────────────────────────────────────────────
    # Docker does not process firewall rules created directly with the nft command.
    if command -v nft &>/dev/null; then
        if sudo nft list tables 2>/dev/null | grep -q .; then
            warn "Active nftables tables detected. Docker does not support rules created directly with nft."
            warn "Use iptables/ip6tables for any rules that must interact with Docker networking."
        else
            info "nftables: no active tables detected ✓"
        fi
    fi

    # ── ufw ───────────────────────────────────────────────────────────────────
    # Docker bypasses ufw for published container ports (-p host:container).
    if command -v ufw &>/dev/null; then
        local ufw_status
        ufw_status=$(sudo ufw status 2>/dev/null | head -1 || true)
        if echo "$ufw_status" | grep -qi 'active'; then
            warn "ufw is active. Docker bypasses ufw rules for published container ports (e.g. -p 8080:80)."
            warn "Containers with published ports will be reachable from the network regardless of ufw rules."
            warn "To restrict access, use iptables rules in the DOCKER-USER chain or bind to 127.0.0.1."
        else
            info "ufw: installed but inactive ✓"
        fi
    else
        info "ufw: not installed ✓"
    fi

    # ── firewalld ────────────────────────────────────────────────────────────
    # Same bypass issue applies to firewalld.
    if command -v firewall-cmd &>/dev/null; then
        if sudo systemctl is-active --quiet firewalld 2>/dev/null; then
            warn "firewalld is active. Docker bypasses firewalld rules for published container ports."
            warn "Use the DOCKER-USER iptables chain to enforce rules on Docker traffic."
        else
            info "firewalld: installed but inactive ✓"
        fi
    else
        info "firewalld: not installed ✓"
    fi

    info "Firewall check complete ✓"
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

# ─── preflight ───────────────��─────────────────────────���──────────────────────
# All read-only checks run here before any change is made to the system.

preflight() {
    info "Running preflight checks..."

    require_sudo
    check_apt_lock
    check_architecture
    check_os
    check_firewall

    # ── conflicting packages ──────────────────────────────────────────────────
    local conflicts=(docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc)
    local found_conflicts=()
    for pkg in "${conflicts[@]}"; do
        dpkg -l "$pkg" 2>/dev/null | grep -q '^ii' && found_conflicts+=("$pkg")
    done
    if [[ ${#found_conflicts[@]} -gt 0 ]]; then
        warn "Conflicting packages detected (will be removed): ${found_conflicts[*]}"
    fi

    # ── docker already fully installed ───────────────────────────────────────
    local engine_packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
    local already_installed=()
    for pkg in "${engine_packages[@]}"; do
        dpkg -l "$pkg" 2>/dev/null | grep -q '^ii' && already_installed+=("$pkg")
    done
    if [[ ${#already_installed[@]} -eq ${#engine_packages[@]} ]]; then
        warn "All Docker Engine packages are already installed:"
        for pkg in "${already_installed[@]}"; do
            warn "  $pkg $(dpkg -l "$pkg" | awk '/^ii/{print $3}')"
        done
        warn "Run uninstall-docker-ubuntu.sh first if you want to reinstall."
        error "Aborting — Docker Engine is already fully installed."
    fi

    # ── apt repo config conflicts ─────────────────────────────────────────────
    local gpg_key="/etc/apt/keyrings/docker.asc"
    local sources_file="/etc/apt/sources.list.d/docker.sources"

    if [[ -f "$gpg_key" ]]; then
        local tmp_key="$WORK_DIR/docker-preflight.asc"
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$tmp_key"
        if sudo cmp -s "$tmp_key" "$gpg_key"; then
            warn "GPG key already exists and is identical — will be skipped: $gpg_key"
        else
            warn "GPG key already exists but differs from upstream: $gpg_key"
            warn "Remove it manually and re-run if you want to replace it."
            error "Aborting — existing GPG key would be overwritten."
        fi
    fi

    if [[ -f "$sources_file" ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        local codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
        local expected
        expected=$(cat <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${codename}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: ${gpg_key}
EOF
)
        local existing
        existing=$(sudo cat "$sources_file")
        if [[ "$existing" == "$expected" ]]; then
            warn "Apt sources file already exists and is identical — will be skipped: $sources_file"
        else
            warn "Apt sources file already exists but differs from expected: $sources_file"
            warn "Remove it manually and re-run if you want to replace it."
            error "Aborting — existing apt sources file would be overwritten."
        fi
    fi

    # ── rootless prerequisites (informational only — user chooses mode later) ─
    if ! check_rootless_prerequisites; then
        warn "Rootless mode prerequisites not fully met (uidmap or subuid/subgid entries missing)."
        warn "The script will install them automatically if you choose rootless mode."
    else
        info "Rootless mode prerequisites: met ✓"
    fi

    info "Preflight checks passed ✓"
}

# ─── remove conflicting packages ───────────────────────────────────────────────

remove_conflicts() {
    local conflicts=(
        docker.io
        docker-compose
        docker-compose-v2
        docker-doc
        podman-docker
        containerd
        runc
    )

    local installed=()
    for pkg in "${conflicts[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
            installed+=("$pkg")
        fi
    done

    if [[ ${#installed[@]} -gt 0 ]]; then
        info "Removing conflicting packages: ${installed[*]}"
        run sudo apt-get remove -y "${installed[@]}"
    else
        info "No conflicting packages found ✓"
    fi
}

# ─── set up Docker apt repository ──────────────────────────────────────────────

setup_docker_repo() {
    info "Setting up Docker's official apt repository..."

    # shellcheck disable=SC1091
    source /etc/os-release
    local codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    local gpg_key="/etc/apt/keyrings/docker.asc"
    local sources_file="/etc/apt/sources.list.d/docker.sources"
    local need_apt_update=false

    # ── GPG key ──────────────────────────────────────────────────────────────
    if [[ -f "$gpg_key" ]]; then
        warn "GPG key already exists and is identical — skipping: $gpg_key"
    else
        run sudo apt-get update -qq
        run sudo apt-get install -y ca-certificates curl
        run sudo install -m 0755 -d /etc/apt/keyrings
        if $DRY_RUN; then
            info "[DRY-RUN] Would download GPG key to: $gpg_key"
        else
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$gpg_key"
            sudo chmod a+r "$gpg_key"
        fi
        need_apt_update=true
        info "GPG key installed ✓"
    fi

    # ── apt sources file ──────────────────────────────────────────────────────
    local expected_sources
    expected_sources=$(cat <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${codename}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: ${gpg_key}
EOF
)
    if [[ -f "$sources_file" ]]; then
        warn "Apt sources file already exists and is identical — skipping: $sources_file"
    else
        if $DRY_RUN; then
            info "[DRY-RUN] Would write apt sources file: $sources_file"
        else
            sudo tee "$sources_file" > /dev/null <<< "$expected_sources"
        fi
        need_apt_update=true
        info "Apt sources file written ✓"
    fi

    if $need_apt_update; then
        run sudo apt-get update -qq
    fi
    info "Docker apt repository configured ✓"
}

# ─── install Docker Engine ─────────────────────────────────────────────────────

install_docker_engine() {
    local packages=(
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
    )

    info "Installing Docker Engine packages..."
    run sudo apt-get install -y "${packages[@]}"
    info "Docker Engine installed ✓"
}

check_rootless_prerequisites() {
    local ok=true

    if ! command -v newuidmap &>/dev/null || ! command -v newgidmap &>/dev/null; then
        ok=false
    fi

    local uid_count=0 gid_count=0
    if grep -q "^${USER}:" /etc/subuid 2>/dev/null; then
        uid_count=$(grep "^${USER}:" /etc/subuid | cut -d: -f3)
    fi
    if grep -q "^${USER}:" /etc/subgid 2>/dev/null; then
        gid_count=$(grep "^${USER}:" /etc/subgid | cut -d: -f3)
    fi
    if [[ "$uid_count" -lt 65536 || "$gid_count" -lt 65536 ]]; then
        ok=false
    fi

    $ok
}

setup_docker_group() {
    if ! getent group docker &>/dev/null; then
        run sudo groupadd docker
    fi
    if groups "$USER" | grep -q '\bdocker\b'; then
        info "User $USER is already in the 'docker' group ✓"
        return
    fi
    run sudo usermod -aG docker "$USER"
    warn "Group change takes effect after next login. Run 'newgrp docker' to apply immediately."
}

setup_rootless() {
    info "Checking rootless prerequisites..."

    if ! check_rootless_prerequisites; then
        warn "Rootless prerequisites not met. Installing uidmap..."
        run sudo apt-get install -y uidmap

        # Ensure /etc/subuid and /etc/subgid have entries for this user
        if ! grep -q "^${USER}:" /etc/subuid 2>/dev/null; then
            run sudo usermod --add-subuids 100000-165535 "$USER"
        fi
        if ! grep -q "^${USER}:" /etc/subgid 2>/dev/null; then
            run sudo usermod --add-subgids 100000-165535 "$USER"
        fi
    fi

    if $DRY_RUN; then
        info "[DRY-RUN] Would run: dockerd-rootless-setuptool.sh install"
        return
    fi

    info "Setting up rootless Docker..."
    dockerd-rootless-setuptool.sh install
    systemctl --user enable docker
    systemctl --user start docker

    # Rootless Docker uses a user-scoped socket; export the correct host.
    local profile_line='export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock'
    if ! grep -qF "$profile_line" "$HOME/.bashrc" 2>/dev/null; then
        echo "$profile_line" >> "$HOME/.bashrc"
        info "Added DOCKER_HOST export to ~/.bashrc"
    fi
    warn "Run 'source ~/.bashrc' or open a new shell for DOCKER_HOST to take effect."
}

post_install() {
    info "Enabling and starting Docker service..."
    run sudo systemctl enable docker
    run sudo systemctl start docker

    echo ""
    echo -e "${YELLOW}=== Docker access mode ===${NC}"
    echo ""
    echo -e "  ${GREEN}A)${NC} Rootless mode  — Docker daemon and containers run as your user (RECOMMENDED)"
    echo    "                    No root-equivalent exposure. Socket is private to your user."
    echo    "                    Best choice for any workstation or shared system."
    echo ""
    echo -e "  ${GREEN}B)${NC} docker group   — run docker without sudo (convenient, but grants root-equivalent"
    echo    "                    access to the Docker socket — effectively passwordless root on the host."
    echo    "                    Only use this on a fully trusted personal machine if rootless is not viable.)"
    echo ""
    echo -e "  ${GREEN}C)${NC} Skip           — manage access yourself; use 'sudo docker' for now"
    echo ""

    if $DRY_RUN; then
        info "[DRY-RUN] Would prompt for access mode choice (A/B/C)"
        info "[DRY-RUN] Option A would: apt install uidmap + dockerd-rootless-setuptool.sh install"
        info "[DRY-RUN] Option B would: groupadd docker + usermod -aG docker $USER"
        return
    fi

    local choice
    read -r -p "$(echo -e "${YELLOW}Choose access mode [A/B/C]:${NC} ")" choice
    case "${choice^^}" in
        A)
            setup_rootless
            ;;
        B)
            warn "Adding $USER to the 'docker' group grants root-equivalent access via the Docker socket."
            warn "Any process running as $USER can escalate to root via: docker run -v /:/host --rm -it alpine chroot /host"
            warn "Only proceed if this is a trusted personal workstation."
            setup_docker_group
            ;;
        C)
            info "Skipping access setup. Use 'sudo docker' until you configure access manually."
            ;;
        *)
            warn "Invalid choice '$choice' — skipping access setup. Use 'sudo docker' for now."
            ;;
    esac
}

# ─── post-install verification ─────────────────────────────────────────────────

verify_install() {
    if $DRY_RUN; then
        info "[DRY-RUN] Would verify: docker --version, docker compose version, sudo docker run hello-world"
        return
    fi
    info "Verifying installation..."
    docker --version       && info "docker CLI ✓"
    docker compose version && info "docker compose ✓"
    info "Running hello-world container..."
    sudo docker run --rm hello-world && info "hello-world ✓"
}

# ─── main ──────────────────────────────────────────────────────────────────────

main() {
    $DRY_RUN && warn "=== DRY-RUN MODE — no changes will be made ==="
    info "=== Docker Engine for Ubuntu — pre-flight & install ==="

    preflight
    remove_conflicts
    setup_docker_repo
    install_docker_engine
    post_install
    verify_install

    info ""
    info "=== Installation complete ==="
    info "Docker service status:    sudo systemctl status docker"
    info "docker group (if chosen): newgrp docker  (or log out and back in)"
    info "Rootless status:          systemctl --user status docker"
}

main "$@"
