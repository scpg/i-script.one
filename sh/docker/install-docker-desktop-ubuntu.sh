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

LOG_TAG="docker-desktop-install"
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

# Wraps mutating commands: executes normally, or prints in dry-run mode.
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
    if [[ "$arch" != "amd64" ]]; then
        error "Docker Desktop requires an x86-64 (amd64) system. Detected: $arch"
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

    local supported=("22.04" "24.04" "26.04")
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

check_kvm() {
    # Docker Desktop on Linux requires KVM virtualisation support.
    if ! grep -qE '(vmx|svm)' /proc/cpuinfo; then
        error "CPU virtualisation extensions (Intel VT-x / AMD-V) not detected. Docker Desktop requires KVM support."
    fi

    if ! sudo modprobe kvm 2>/dev/null; then
        error "Failed to load kvm kernel module. Docker Desktop requires KVM."
    fi

    if grep -q 'vmx' /proc/cpuinfo; then
        run sudo modprobe kvm_intel 2>/dev/null || warn "Could not load kvm_intel module."
    elif grep -q 'svm' /proc/cpuinfo; then
        run sudo modprobe kvm_amd 2>/dev/null || warn "Could not load kvm_amd module."
    fi

    if [[ ! -e /dev/kvm ]]; then
        error "/dev/kvm device not found after loading KVM modules. Docker Desktop requires KVM access."
    fi

    if ! ls -la /dev/kvm | grep -qE '(kvm|root)'; then
        warn "/dev/kvm exists but group ownership is unexpected. Checking access..."
    fi
    if [[ ! -r /dev/kvm ]] || [[ ! -w /dev/kvm ]]; then
        local kvm_group
        kvm_group=$(stat -c '%G' /dev/kvm)
        warn "User $USER does not have read/write access to /dev/kvm."
        info "Adding $USER to the '$kvm_group' group..."
        run sudo usermod -aG "$kvm_group" "$USER"
        warn "You must log out and back in (or run 'newgrp $kvm_group') for group changes to take effect."
    else
        info "KVM: /dev/kvm accessible ✓"
    fi
}

check_gnome_terminal() {
    # Docker Desktop requires gnome-terminal when the desktop environment is not GNOME.
    local de="${XDG_CURRENT_DESKTOP:-}"
    if [[ "$de" != *"GNOME"* ]]; then
        if ! command -v gnome-terminal &>/dev/null; then
            info "Non-GNOME desktop detected ($de). Installing gnome-terminal (required by Docker Desktop)..."
            run sudo apt-get install -y gnome-terminal
        else
            info "gnome-terminal: already installed ✓"
        fi
    else
        info "Desktop environment: GNOME — gnome-terminal check skipped ✓"
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
    check_architecture
    check_os
    check_kvm

    # ── gnome-terminal ────────────────────────────────────────────────────────
    local de="${XDG_CURRENT_DESKTOP:-}"
    if [[ "$de" != *"GNOME"* ]] && ! command -v gnome-terminal &>/dev/null; then
        warn "Non-GNOME desktop detected ($de) and gnome-terminal is not installed."
        warn "gnome-terminal will be installed automatically (required by Docker Desktop)."
    fi

    # ── conflicting packages ──────────────────────────────────────────────────
    local conflicts=(docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc)
    local found_conflicts=()
    for pkg in "${conflicts[@]}"; do
        dpkg -l "$pkg" 2>/dev/null | grep -q '^ii' && found_conflicts+=("$pkg")
    done
    if [[ ${#found_conflicts[@]} -gt 0 ]]; then
        warn "Conflicting packages detected (will be removed): ${found_conflicts[*]}"
    fi

    # ── docker-desktop already installed ─────────────────────────────────────
    if dpkg -l docker-desktop 2>/dev/null | grep -q '^ii'; then
        local ver
        ver=$(dpkg -l docker-desktop | awk '/^ii/{print $3}')
        warn "Docker Desktop $ver is already installed."
        warn "Run uninstall-docker-desktop-ubuntu.sh first if you want to reinstall."
        error "Aborting — Docker Desktop is already installed."
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

# ─── download and install Docker Desktop ───────────────────────────────────────

install_docker_desktop() {
    local deb_url="https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb"
    local deb_name="docker-desktop-amd64.deb"
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/docker-install"
    local deb_file=""

    if $DRY_RUN; then
        info "[DRY-RUN] Would look for $deb_name in ~/Downloads, then $cache_dir"
        info "[DRY-RUN] Would download from: $deb_url (if not found or size mismatch)"
        info "[DRY-RUN] Would install: $deb_name"
        return
    fi

    # Fetch remote Content-Length once — used to validate any candidate file.
    # Docker Desktop does not publish a separate checksum file, so size is the
    # best available integrity signal without re-downloading the whole package.
    info "Checking remote file size..."
    local remote_size
    remote_size=$(curl -fsSI "$deb_url" 2>/dev/null \
        | awk 'tolower($1)=="content-length:" {gsub(/\r/,"",$2); print $2}' \
        | tail -1)
    if [[ -z "$remote_size" ]]; then
        warn "Could not retrieve remote Content-Length — will download unconditionally."
    fi

    # Helper: returns 0 if the file at $1 matches $remote_size (or remote_size unknown)
    _size_ok() {
        [[ -z "$remote_size" ]] && return 0
        local sz
        sz=$(stat -c '%s' "$1")
        [[ "$sz" == "$remote_size" ]]
    }

    # 1. Check ~/Downloads first (browser-downloaded file)
    local downloads_candidate="$HOME/Downloads/$deb_name"
    if [[ -f "$downloads_candidate" ]]; then
        if _size_ok "$downloads_candidate"; then
            info "Found matching .deb in ~/Downloads — using it ✓"
            deb_file="$downloads_candidate"
        else
            local sz; sz=$(stat -c '%s' "$downloads_candidate")
            warn "~/Downloads/$deb_name exists but size differs (local: $sz, remote: ${remote_size:-unknown}) — ignoring."
        fi
    fi

    # 2. Check cache dir
    local cached_file="$cache_dir/$deb_name"
    if [[ -z "$deb_file" && -f "$cached_file" ]]; then
        if _size_ok "$cached_file"; then
            info "Found matching .deb in cache — skipping download ✓"
            deb_file="$cached_file"
        else
            local sz; sz=$(stat -c '%s' "$cached_file")
            info "Cached file size mismatch (local: $sz, remote: ${remote_size:-unknown}) — re-downloading..."
        fi
    fi

    # 3. Download if neither candidate matched
    if [[ -z "$deb_file" ]]; then
        mkdir -p "$cache_dir"
        info "Downloading Docker Desktop..."
        curl -fL --progress-bar "$deb_url" -o "$cached_file"
        deb_file="$cached_file"
    fi

    # On Ubuntu 26.04 the apt hook /usr/bin/apt_hook_ubuntu_virt may be missing,
    # causing apt to abort with exit 127 before dpkg can record the installation.
    # Workaround: install a temporary no-op stub for the duration of this apt call.
    local hook=/usr/bin/apt_hook_ubuntu_virt
    local hook_created=false
    if [[ ! -x "$hook" ]]; then
        warn "apt hook $hook is missing (Ubuntu 26.04 known issue) — installing temporary stub."
        sudo bash -c "printf '#!/bin/sh\nexit 0\n' > $hook && chmod +x $hook"
        hook_created=true
    fi

    info "Installing Docker Desktop from: $deb_file"
    local apt_rc=0
    # apt handles dependencies; the permission error about sandboxed downloads is benign.
    sudo apt-get install -y "$deb_file" 2>&1 \
        | grep -v "Sanity check on file" || apt_rc=$?

    # Remove the stub we created — leave no trace
    if $hook_created; then
        sudo rm -f "$hook"
    fi

    if [[ $apt_rc -ne 0 ]]; then
        error "apt-get install failed (exit $apt_rc)."
    fi

    info "Docker Desktop installed ✓"
}

# ─── credential store setup ───────────────────────────────────────────────────

setup_credentials() {
    echo ""
    echo -e "${YELLOW}=== Credential store setup ===${NC}"
    echo ""
    echo "  Docker Desktop needs a credential store to securely save your Docker Hub"
    echo "  (and other registry) login credentials. Without one, credentials are stored"
    echo "  in plaintext in ~/.docker/config.json."
    echo ""
    echo "  Two supported options:"
    echo ""
    echo -e "  ${GREEN}A)${NC} secretservice — stores credentials in GNOME Keyring (recommended on Ubuntu desktop)"
    echo    "                   Unlocked automatically at login; completely silent — no prompts ever."
    echo    "                   Requires a graphical session (not suitable for headless/SSH-only)."
    echo ""
    echo -e "  ${GREEN}B)${NC} pass (no passphrase GPG key) — GPG-encrypted file store, no passphrase set"
    echo    "                   Silent operation, no prompts. GPG key is unprotected on disk."
    echo    "                   Acceptable on a LUKS full-disk-encrypted personal machine."
    echo    "                   NOTE: using a GPG passphrase is NOT recommended — it causes known"
    echo    "                   Docker Desktop bugs: startup prompts, update hangs, and command"
    echo    "                   freezes that are unresolved upstream since 2023."
    echo ""
    echo -e "  ${GREEN}C)${NC} Skip — leave plaintext config.json in place (least secure, easiest)."
    echo ""

    if $DRY_RUN; then
        info "[DRY-RUN] Would prompt for credential store choice (A/B/C)"
        info "[DRY-RUN] Option A would: apt install golang-docker-credential-helpers + set credsStore=secretservice"
        info "[DRY-RUN] Option B would: apt install pass gpg + generate no-passphrase GPG key + pass init + set credsStore=pass"
        return
    fi

    local choice
    read -r -p "$(echo -e "${YELLOW}Choose credential store [A/B/C]:${NC} ")" choice

    case "${choice^^}" in
        A) setup_credentials_secretservice ;;
        B) setup_credentials_pass ;;
        C) warn "Skipping credential store setup. Credentials will be stored in plaintext ~/.docker/config.json" ;;
        *) warn "Invalid choice '$choice' — skipping credential store setup." ;;
    esac
}

setup_credentials_secretservice() {
    info "Setting up secretservice (GNOME Keyring) credential store..."
    info "Purpose: stores Docker registry credentials in GNOME Keyring, which is unlocked"
    info "automatically when you log in to your desktop. No passphrase prompts, ever."

    if ! dpkg -l golang-docker-credential-helpers 2>/dev/null | grep -q '^ii'; then
        run sudo apt-get install -y golang-docker-credential-helpers
    else
        info "golang-docker-credential-helpers: already installed ✓"
    fi

    # Verify the helper binary is available
    if ! command -v docker-credential-secretservice &>/dev/null; then
        error "docker-credential-secretservice binary not found after install. Cannot continue."
    fi

    _set_creds_store "secretservice"
    info "Credential store set to secretservice ✓"
    info "Your Docker login credentials will be stored silently in GNOME Keyring."
    info "Run 'docker login' to save credentials — no passphrase will be asked."
}

setup_credentials_pass() {
    info "Setting up pass (GPG-encrypted file store) credential store..."
    info "Purpose: stores Docker registry credentials in GPG-encrypted files under ~/.password-store."
    info "A GPG key with NO passphrase will be created so Docker Desktop operates silently."
    warn "The GPG private key will not be passphrase-protected. Ensure your disk is encrypted (LUKS)."

    # Install dependencies
    local pkgs=()
    command -v gpg  &>/dev/null || pkgs+=(gnupg)
    command -v pass &>/dev/null || pkgs+=(pass)
    if [[ ${#pkgs[@]} -gt 0 ]]; then
        run sudo apt-get install -y "${pkgs[@]}"
    else
        info "gpg and pass: already installed ✓"
    fi

    # Generate a no-passphrase GPG key dedicated to Docker credentials
    local key_name="Docker Desktop Credentials"
    local key_email="docker-credentials@localhost"

    if gpg --list-keys "$key_email" &>/dev/null; then
        info "GPG key for $key_email already exists — reusing it."
    else
        info "Generating GPG key (no passphrase) for: $key_name <$key_email>"
        local key_spec="$WORK_DIR/gpg-key-spec"
        cat > "$key_spec" <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: ${key_name}
Name-Email: ${key_email}
Expire-Date: 0
%commit
EOF
        gpg --batch --gen-key "$key_spec"
        info "GPG key generated ✓"
    fi

    # Initialise the pass store with this key
    local key_id
    key_id=$(gpg --list-keys --with-colons "$key_email" | awk -F: '/^pub/{print $5}')
    if [[ -d "$HOME/.password-store" ]]; then
        info "pass store already initialised — re-initialising with Docker key."
    fi
    pass init "$key_id"
    info "pass store initialised ✓"

    _set_creds_store "pass"
    info "Credential store set to pass ✓"
    info "Your Docker login credentials will be GPG-encrypted with no passphrase prompt."
    info "Run 'docker login' to save credentials."
}

# Writes the credsStore key into ~/.docker/config.json, creating the file if absent.
_set_creds_store() {
    local store="$1"
    local config="$HOME/.docker/config.json"

    mkdir -p "$HOME/.docker"

    if [[ -f "$config" ]]; then
        # Use python3 to safely merge the key without disturbing other config entries.
        python3 - "$config" "$store" <<'PYEOF'
import sys, json
path, store = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)
cfg["credsStore"] = store
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
    else
        printf '{\n  "credsStore": "%s"\n}\n' "$store" > "$config"
    fi
}

# ─── post-install verification ─────────────────────────────────────────────────

verify_install() {
    if $DRY_RUN; then
        info "[DRY-RUN] Would verify docker-desktop package and binary presence"
        return
    fi
    info "Verifying installation..."

    # Confirm the package is registered
    local dpkg_state
    dpkg_state=$(dpkg -l docker-desktop 2>/dev/null | awk '/^[a-z]/{print $1}' | tail -1)
    local ver
    ver=$(dpkg -l docker-desktop 2>/dev/null | awk '/docker-desktop/{print $3}' | tail -1)
    case "$dpkg_state" in
        ii)
            info "docker-desktop package installed: $ver ✓"
            ;;
        iF|iU|iH)
            warn "docker-desktop ($ver) is present but in a partial state ($dpkg_state)."
            warn "Try running: sudo dpkg --configure -a"
            ;;
        "")
            error "docker-desktop package not found in dpkg after installation."
            ;;
        *)
            warn "docker-desktop ($ver) dpkg state: $dpkg_state — installation may be incomplete."
            ;;
    esac

    # Docker Desktop puts its binaries in /opt/docker-desktop/bin, which is added
    # to PATH only in a new login shell via /etc/profile.d. Check the binary directly.
    local docker_bin
    docker_bin=$(command -v docker 2>/dev/null || echo "/opt/docker-desktop/bin/docker")
    if [[ -x "$docker_bin" ]]; then
        info "docker binary present: $docker_bin ✓"
    else
        warn "docker binary not found on PATH yet — open a new terminal or log out and back in."
    fi

    info "Installation complete. Start Docker Desktop from your application menu"
    info "or run: systemctl --user start docker-desktop"
    info "Note: 'docker' will be available on PATH in your next login shell session."
}

# ─── main ──────────────────────────────────────────────────────────────────────

main() {
    $DRY_RUN && warn "=== DRY-RUN MODE — no changes will be made ==="
    info "=== Docker Desktop for Ubuntu — pre-flight & install ==="

    preflight
    check_gnome_terminal
    remove_conflicts
    setup_docker_repo
    install_docker_desktop
    setup_credentials
    verify_install

    info ""
    info "=== Installation complete ==="
    info "Start Docker Desktop:  systemctl --user start docker-desktop"
    info "Enable on login:       systemctl --user enable docker-desktop"
}

main "$@"
