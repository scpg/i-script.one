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

LOG_TAG="docker-uninstall"
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

check_leftover_traces() {
    # Removable by this script (with confirmation)
    local removable_paths=()
    local removable_descs=()

    [[ -d /var/lib/docker ]]        && removable_paths+=("/var/lib/docker")                            && removable_descs+=("Images, containers, volumes")
    [[ -d /var/lib/containerd ]]    && removable_paths+=("/var/lib/containerd")                        && removable_descs+=("Containerd snapshots")
    getent group docker &>/dev/null && removable_paths+=("group:docker")                               && removable_descs+=("System group")
    [[ -f "$HOME/.config/systemd/user/docker.service" ]] \
                                    && removable_paths+=("~/.config/systemd/user/docker.service")      && removable_descs+=("Rootless systemd unit — causes password prompt at login")
    [[ -d "$HOME/.local/share/docker" ]] \
                                    && removable_paths+=("~/.local/share/docker")                      && removable_descs+=("Rootless daemon data directory")
    if [[ -f "$HOME/.docker/config.json" ]] && \
       python3 -c "import json,sys; c=json.load(open('$HOME/.docker/config.json')); sys.exit(0 if c.get('currentContext')=='desktop-linux' or c.get('credsStore') else 1)" 2>/dev/null; then
        removable_paths+=("~/.docker/config.json entries")
        removable_descs+=("Stale context (desktop-linux) and/or credsStore — triggers credential prompts")
    fi

    # Inform only — user must handle manually
    local inform_paths=()
    local inform_descs=()

    [[ -d /etc/docker ]]                                               && inform_paths+=("/etc/docker")                               && inform_descs+=("Daemon config files")
    [[ -f /etc/apt/keyrings/docker.asc ]]                             && inform_paths+=("/etc/apt/keyrings/docker.asc")              && inform_descs+=("Docker GPG key")
    [[ -f /etc/apt/sources.list.d/docker.sources ]]                   && inform_paths+=("/etc/apt/sources.list.d/docker.sources")    && inform_descs+=("Docker apt repo")
    if [[ -f "$HOME/.bashrc" ]] && grep -q 'DOCKER_HOST' "$HOME/.bashrc"; then
        inform_paths+=("DOCKER_HOST in ~/.bashrc")
        inform_descs+=("Rootless socket export — remove manually")
    fi

    if [[ ${#removable_paths[@]} -eq 0 && ${#inform_paths[@]} -eq 0 ]]; then
        info "No Docker packages installed and no leftover traces found. Nothing to do."
        exit 0
    fi

    echo ""
    echo -e "${YELLOW}⚠  Docker is not installed, but traces of a previous installation were found.${NC}"
    echo ""

    if [[ ${#removable_paths[@]} -gt 0 ]]; then
        echo -e "${RED}  The following will be PERMANENTLY REMOVED (cannot be recovered):${NC}"
        for i in "${!removable_paths[@]}"; do
            echo -e "  ${RED}•${NC} ${removable_paths[$i]} — ${removable_descs[$i]}"
        done
        echo ""
    fi

    if [[ ${#inform_paths[@]} -gt 0 ]]; then
        echo -e "${YELLOW}  The following require manual removal — this script will not touch them:${NC}"
        for i in "${!inform_paths[@]}"; do
            echo -e "  ${YELLOW}•${NC} ${inform_paths[$i]} — ${inform_descs[$i]}"
        done
        echo ""
    fi

    if [[ ${#removable_paths[@]} -eq 0 ]]; then
        info "No automatically removable traces found. Nothing to do."
        exit 0
    fi

    if ! confirm "Permanently remove the items listed in red above?"; then
        info "No changes made."
        exit 0
    fi

    # ── perform removal ───────────────────────────────────────────────────────
    if [[ -d /var/lib/docker ]]; then
        info "Removing /var/lib/docker..."
        run sudo rm -rf /var/lib/docker
    fi

    if [[ -d /var/lib/containerd ]]; then
        info "Removing /var/lib/containerd..."
        run sudo rm -rf /var/lib/containerd
    fi

    if getent group docker &>/dev/null; then
        info "Removing 'docker' group..."
        run sudo groupdel docker 2>/dev/null || true
    fi

    local rootless_unit="$HOME/.config/systemd/user/docker.service"
    if [[ -f "$rootless_unit" ]]; then
        info "Stopping and disabling rootless Docker daemon..."
        run systemctl --user stop docker 2>/dev/null || true
        run systemctl --user disable docker 2>/dev/null || true
        run rm -f "$rootless_unit"
        run systemctl --user daemon-reload 2>/dev/null || true
        info "Rootless systemd unit removed ✓"
    fi

    if [[ -d "$HOME/.local/share/docker" ]]; then
        info "Removing rootless Docker data directory..."
        run rm -rf "$HOME/.local/share/docker"
    fi

    local docker_cfg="$HOME/.docker/config.json"
    if [[ -f "$docker_cfg" ]]; then
        info "Cleaning stale entries from ~/.docker/config.json..."
        if ! $DRY_RUN; then
            python3 - "$docker_cfg" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)
changed = False
if cfg.get("currentContext") == "desktop-linux":
    del cfg["currentContext"]
    changed = True
if "credsStore" in cfg:
    del cfg["credsStore"]
    changed = True
if changed:
    with open(path, "w") as f:
        json.dump(cfg, f, indent=4)
    print("  Removed stale currentContext / credsStore entries")
else:
    print("  Nothing to clean in config.json")
PYEOF
        else
            info "[DRY-RUN] Would remove stale currentContext/credsStore from $docker_cfg"
        fi
    fi

    info "Removable traces cleaned up ✓"
    exit 0
}

# ─── preflight ────────────────────────────────────────────────────────────────
# All read-only checks run here before any change is made to the system.

preflight() {
    info "Running preflight checks..."

    require_sudo
    check_apt_lock

    # ── verify something is actually installed ────────────────────────────────
    local packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
    local found=false
    for pkg in "${packages[@]}"; do
        dpkg -l "$pkg" 2>/dev/null | grep -q '^ii' && found=true && break
    done
    if ! $found; then
        warn "No Docker Engine packages are installed."
        check_leftover_traces
    fi

    # ── list what will be removed ─────────────────────────────────────────────
    info "The following Docker Engine packages are installed and will be removed:"
    for pkg in "${packages[@]}" docker-ce-rootless-extras; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
            info "  $pkg $(dpkg -l "$pkg" | awk '/^ii/{print $3}')"
        fi
    done

    # ── inventory: images, containers, volumes (queried while daemon is up) ───
    if sudo systemctl is-active --quiet docker 2>/dev/null; then
        echo ""
        echo -e "${YELLOW}  Images that will be deleted if you confirm:${NC}"
        if sudo docker images --format "    • {{.Repository}}:{{.Tag}}  ({{.Size}})" 2>/dev/null | grep -q .; then
            sudo docker images --format "    • {{.Repository}}:{{.Tag}}  ({{.Size}})" 2>/dev/null
        else
            echo    "    (none)"
        fi

        echo ""
        echo -e "${YELLOW}  Containers that will be deleted if you confirm:${NC}"
        if sudo docker ps -a --format "    • {{.Names}}  [{{.Status}}]  {{.Image}}" 2>/dev/null | grep -q .; then
            sudo docker ps -a --format "    • {{.Names}}  [{{.Status}}]  {{.Image}}" 2>/dev/null
        else
            echo    "    (none)"
        fi

        echo ""
        echo -e "${YELLOW}  Named volumes that will be deleted if you confirm:${NC}"
        if sudo docker volume ls --format "    • {{.Name}}" 2>/dev/null | grep -q .; then
            sudo docker volume ls --format "    • {{.Name}}" 2>/dev/null
        else
            echo    "    (none)"
        fi
        echo ""
    else
        warn "Docker daemon is not running — cannot list images/containers/volumes."
        warn "Data directories will still be offered for deletion."
    fi

    # ── data directories that may be removed ─────────────────────────────────
    for d in /var/lib/docker /var/lib/containerd; do
        [[ -d "$d" ]] && warn "Data directory present (removal will be confirmed separately): $d"
    done

    info "Preflight checks passed ✓"
}

# ─── stop docker ───────────────────────────────────────────────────────────────

stop_docker() {
    if sudo systemctl is-active --quiet docker 2>/dev/null; then
        info "Stopping Docker service..."
        run sudo systemctl stop docker
        run sudo systemctl stop docker.socket 2>/dev/null || true
    else
        info "Docker service is not running ✓"
    fi
    run sudo systemctl disable docker 2>/dev/null || true
}

# ─── remove packages ───────────────────────────────────────────────────────────

remove_packages() {
    local packages=(
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
        docker-ce-rootless-extras
    )

    local installed=()
    for pkg in "${packages[@]}"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
            installed+=("$pkg")
        fi
    done

    if [[ ${#installed[@]} -gt 0 ]]; then
        info "Removing packages: ${installed[*]}"
        run sudo apt-get purge -y "${installed[@]}"
        run sudo apt-get autoremove -y
    else
        info "No Docker Engine packages found to remove ✓"
    fi
}

# ─── remove persistent data ────────────────────────────────────────────────────

remove_data() {
    # ── images & containers ───────────────────────────────────────────────────
    local img_dir="/var/lib/docker"
    if [[ -d "$img_dir" ]]; then
        echo ""
        echo -e "${RED}⚠  IMAGES & CONTAINERS${NC}"
        echo    "   Directory: $img_dir"
        echo    "   Contains all downloaded images and stopped containers."
        echo    "   This data can be re-downloaded but the process may take time."
        echo ""

        if confirm "Delete all Docker images and containers? ($img_dir)"; then
            info "Removing images and containers..."
            run sudo rm -rf "$img_dir"
            info "Images and containers removed ✓"
        else
            info "Skipping — $img_dir left intact."
        fi
    else
        info "No Docker images/containers directory found ✓"
    fi

    # ── named volumes (user data) ─────────────────────────────────────────────
    # Named volumes live inside /var/lib/docker/volumes — but if the user chose
    # to keep $img_dir above, we still offer to enumerate and delete volumes
    # explicitly. If $img_dir was already deleted, nothing remains to list.
    local vol_dir="/var/lib/docker/volumes"
    if [[ -d "$vol_dir" ]]; then
        local volumes=()
        # List volume names (each is a subdirectory, excluding the metadata file)
        while IFS= read -r -d '' vol; do
            [[ -d "$vol" ]] && volumes+=("$(basename "$vol")")
        done < <(find "$vol_dir" -mindepth 1 -maxdepth 1 -not -name 'metadata.db' -print0 2>/dev/null)

        echo ""
        echo -e "${RED}⚠  NAMED VOLUMES — PERMANENT USER DATA LOSS${NC}"
        echo    "   Directory: $vol_dir"
        if [[ ${#volumes[@]} -gt 0 ]]; then
            echo    "   The following named volumes were found:"
            for v in "${volumes[@]}"; do
                echo    "     • $v"
            done
        else
            echo    "   No named volumes found inside $vol_dir."
        fi
        echo ""
        echo -e "${RED}   WARNING: Named volumes may contain databases, application data, or any"
        echo    "   other files created inside your containers. This CANNOT be recovered."
        echo -e "   Only confirm if you are certain this data is no longer needed.${NC}"
        echo ""
        if confirm "PERMANENTLY DELETE all named volumes and their data?"; then
            info "Removing named volumes..."
            run sudo rm -rf "$vol_dir"
            info "Named volumes removed ✓"
        else
            info "Skipping — named volumes left intact in $vol_dir"
        fi
    fi

    # ── containerd data ───────────────────────────────────────────────────────
    local containerd_dir="/var/lib/containerd"
    if [[ -d "$containerd_dir" ]]; then
        echo ""
        echo -e "${YELLOW}⚠  CONTAINERD DATA${NC}"
        echo    "   Directory: $containerd_dir"
        echo    "   Contains containerd's internal image and snapshot store."
        echo    "   Safe to remove if Docker Engine is being fully uninstalled."
        echo ""
        if confirm "Delete containerd data? ($containerd_dir)"; then
            info "Removing containerd data..."
            run sudo rm -rf "$containerd_dir"
            info "Containerd data removed ✓"
        else
            info "Skipping — $containerd_dir left intact."
        fi
    else
        info "No containerd data directory found ✓"
    fi
}

# ─── remove repository config ──────────────────────────────────────────────────

remove_repo_config() {
    local gpg_key="/etc/apt/keyrings/docker.asc"
    local sources_file="/etc/apt/sources.list.d/docker.sources"
    local found=false

    [[ -f "$gpg_key" ]]     && found=true
    [[ -f "$sources_file" ]] && found=true

    if ! $found; then
        info "No Docker repository config found ✓"
        return
    fi

    if confirm "Remove Docker apt repository configuration (GPG key + sources file)?"; then
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

# ─── remove user from docker group ────────────────────────────────────────────

remove_user_from_group() {
    if getent group docker &>/dev/null; then
        if groups "$USER" | grep -q '\bdocker\b'; then
            info "Removing $USER from the 'docker' group..."
            run sudo gpasswd -d "$USER" docker
            warn "Group change takes effect after next login."
        else
            info "User $USER is not in the 'docker' group ✓"
        fi
        # Remove the group only if it has no members left
        if $DRY_RUN; then
            info "[DRY-RUN] Would remove 'docker' group if empty"
        else
            if [[ -z "$(getent group docker | cut -d: -f4)" ]]; then
                sudo groupdel docker 2>/dev/null || true
                info "Removed empty 'docker' group ✓"
            fi
        fi
    fi
}

# ─── main ──────────────────────────────────────────────────────────────────────

main() {
    $DRY_RUN && warn "=== DRY-RUN MODE — no changes will be made ==="
    info "=== Docker Engine for Ubuntu — full uninstall ==="

    preflight
    stop_docker
    remove_packages
    remove_data
    remove_repo_config
    remove_user_from_group

    info ""
    info "=== Uninstall complete ==="
}

main "$@"
