#!/bin/bash

# 1Password Installation Script for Linux (Debian/Ubuntu)
# This script installs both the 1Password desktop app and CLI (op)
# Based on official 1Password documentation

set -e  # Exit on any error

# Verbose logging function
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "🔍 [VERBOSE] $1"
    fi
}

# Enhanced echo function that respects verbose mode
log_step() {
    echo "$1"
    if [ "$VERBOSE" = true ] && [ -n "$2" ]; then
        echo "🔍 [VERBOSE] $2"
    fi
}

# Function to check if a URL is reachable
check_connectivity() {
    local url="$1"
    local description="$2"
    
    log_step "🌐 Checking connectivity to $description..." "Testing connection to: $url"
    
    if [ "$VERBOSE" = true ]; then
        log_verbose "Running: curl -s --head --max-time 10 \"$url\""
    fi
    
    if ! curl -s --head --max-time 10 "$url" > /dev/null 2>&1; then
        echo "❌ Error: Cannot reach $description ($url)"
        echo "   Please check your internet connection and try again."
        log_verbose "Connection test failed for $url"
        exit 1
    fi
    echo "✓ Connection to $description successful"
    log_verbose "Connection test passed for $url"
}

# Function to verify GPG signature
verify_gpg_key() {
    local key_file="$1"
    local expected_fingerprint="3FEF9748469ADBE15DA7CA80AC2D62742012EA22"
    
    log_step "🔐 Verifying GPG key authenticity..." "Expected fingerprint: $expected_fingerprint"
    
    local temp_keyring=$(mktemp)
    log_verbose "Created temporary keyring: $temp_keyring"
    
    if [ "$VERBOSE" = true ]; then
        log_verbose "Running: gpg --no-default-keyring --keyring \"$temp_keyring\" --import \"$key_file\""
    fi
    
    if gpg --no-default-keyring --keyring "$temp_keyring" --import "$key_file" 2>/dev/null; then
        log_verbose "GPG key imported successfully into temporary keyring"
        
        if [ "$VERBOSE" = true ]; then
            log_verbose "Checking fingerprint in imported key..."
            gpg --no-default-keyring --keyring "$temp_keyring" --fingerprint 2>/dev/null | head -10
        fi
        
        if gpg --no-default-keyring --keyring "$temp_keyring" --fingerprint 2>/dev/null | tr -d ' ' | grep -q "$expected_fingerprint"; then
            echo "✓ GPG key fingerprint verified: $expected_fingerprint"
            log_verbose "Fingerprint match confirmed"
            rm -f "$temp_keyring"
            return 0
        else
            echo "❌ Error: GPG key fingerprint does not match expected value"
            echo "   Expected: $expected_fingerprint"
            log_verbose "Fingerprint verification failed"
            rm -f "$temp_keyring"
            return 1
        fi
    else
        echo "❌ Error: Failed to import GPG key for verification"
        log_verbose "GPG key import failed"
        rm -f "$temp_keyring"
        return 1
    fi
}

# Function to download and verify GPG key
download_and_verify_key() {
    local url="$1"
    local output_file="$2"
    local description="$3"
    
    log_step "📥 Downloading $description..." "From: $url"
    local temp_key=$(mktemp)
    log_verbose "Created temporary file: $temp_key"
    
    if [ "$VERBOSE" = true ]; then
        log_verbose "Running: curl -sS \"$url\" -o \"$temp_key\""
    fi
    
    if curl -sS "$url" -o "$temp_key"; then
        log_verbose "Download completed successfully"
        if verify_gpg_key "$temp_key"; then
            log_verbose "Installing verified key to: $output_file"
            sudo gpg --dearmor --output "$output_file" < "$temp_key"
            rm -f "$temp_key"
            echo "✓ $description installed and verified"
            log_verbose "Key installation completed"
        else
            rm -f "$temp_key"
            exit 1
        fi
    else
        echo "❌ Error: Failed to download $description"
        log_verbose "Download failed for $url"
        rm -f "$temp_key"
        exit 1
    fi
}

# Parse command line arguments
VERBOSE=false
for arg in "$@"; do
    case $arg in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Install 1Password desktop app and CLI on Linux (Debian/Ubuntu)"
            echo ""
            echo "OPTIONS:"
            echo "  -v, --verbose    Show detailed output for each step"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "This script will:"
            echo "  1. Verify system compatibility"
            echo "  2. Check network connectivity"
            echo "  3. Download and verify GPG keys"
            echo "  4. Add 1Password repository"
            echo "  5. Install 1Password app and CLI"
            echo "  6. Verify installation"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

echo "🔐 Installing 1Password Desktop App and CLI..."
log_verbose "Script started with verbose mode enabled"

# Request sudo credentials upfront
echo "🔑 This script requires administrator privileges to install packages."
echo "   You may be prompted for your password..."
if ! sudo -v; then
    echo "❌ Error: Administrator privileges are required to run this script."
    exit 1
fi
log_verbose "Sudo credentials verified successfully"

# Keep sudo session alive throughout the script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
log_verbose "Sudo keep-alive background process started (PID: $SUDO_KEEPALIVE_PID)"

# Function to cleanup sudo keep-alive on exit
cleanup_sudo() {
    if [ -n "$SUDO_KEEPALIVE_PID" ]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
        log_verbose "Sudo keep-alive process terminated"
    fi
}

# Set trap to cleanup on script exit
trap cleanup_sudo EXIT

# Check if running on supported system
if ! command -v dpkg &> /dev/null; then
    echo "❌ Error: This script requires a Debian-based system (Ubuntu, Debian, etc.)"
    log_verbose "dpkg command not found - system not supported"
    exit 1
fi
log_verbose "System compatibility check passed - dpkg found"

# Check connectivity to required URLs
log_step "🔍 Performing connectivity checks..." "Testing access to 1Password servers"
check_connectivity "https://downloads.1password.com/linux/keys/1password.asc" "1Password GPG key server"
check_connectivity "https://downloads.1password.com/linux/debian/debsig/1password.pol" "1Password policy server"

# Step 1: Add the GPG key for the 1Password apt repository
echo "📋 Adding 1Password GPG key..."
download_and_verify_key "https://downloads.1password.com/linux/keys/1password.asc" \
    "/usr/share/keyrings/1password-archive-keyring.gpg" \
    "1Password GPG key"

# Step 2: Add the 1Password apt repository
log_step "📦 Adding 1Password repository..." "Architecture: $(dpkg --print-architecture)"
log_verbose "Creating repository entry in /etc/apt/sources.list.d/1password.list"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list > /dev/null
log_verbose "Repository entry created successfully"

# Step 3: Add the debsig-verify policy
log_step "🔑 Configuring package verification policy..." "Setting up debsig-verify for automatic package verification"
log_verbose "Creating policy directory: /etc/debsig/policies/AC2D62742012EA22/"
sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/

log_verbose "Downloading 1Password policy file..."
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
  sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol > /dev/null
log_verbose "Policy file installed successfully"

log_verbose "Creating debsig keyring directory: /usr/share/debsig/keyrings/AC2D62742012EA22"
sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
download_and_verify_key "https://downloads.1password.com/linux/keys/1password.asc" \
    "/usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg" \
    "1Password debsig GPG key"

# Step 4: Update package list
log_step "🔄 Updating package lists..." "Refreshing package information from all repositories"

# Check if 1Password repository is accessible before updating
check_connectivity "https://downloads.1password.com/linux/debian/$(dpkg --print-architecture)/stable" "1Password package repository"

log_verbose "Running: sudo apt update"
if [ "$VERBOSE" = true ]; then
    sudo apt update
else
    sudo apt update > /dev/null 2>&1
fi
log_verbose "Package lists updated successfully"

# Step 5: Install both 1Password desktop app and CLI
log_step "⬇️  Installing 1Password desktop app and CLI..." "Installing packages: 1password 1password-cli"
log_verbose "Running: sudo apt install -y 1password 1password-cli"

if [ "$VERBOSE" = true ]; then
    sudo apt install -y 1password 1password-cli
else
    sudo apt install -y 1password 1password-cli > /dev/null 2>&1
fi
log_verbose "Package installation completed"

# Step 6: Verify package signatures (if debsig-verify is available)
if command -v debsig-verify &> /dev/null; then
    log_step "🔍 Verifying installed package signatures..." "Using debsig-verify to check package authenticity"
    
    if ls /var/cache/apt/archives/1password*.deb 1> /dev/null 2>&1; then
        log_verbose "Found 1Password .deb files in apt cache"
        for deb_file in /var/cache/apt/archives/1password*.deb; do
            log_verbose "Verifying signature for: $(basename "$deb_file")"
            if [ "$VERBOSE" = true ]; then
                if debsig-verify "$deb_file"; then
                    echo "✓ Package signature verified: $(basename "$deb_file")"
                else
                    echo "⚠️  Warning: Could not verify signature for $(basename "$deb_file")"
                    echo "   Package was installed from trusted repository, but signature verification failed"
                fi
            else
                if debsig-verify "$deb_file" 2>/dev/null; then
                    echo "✓ Package signature verified: $(basename "$deb_file")"
                else
                    echo "⚠️  Warning: Could not verify signature for $(basename "$deb_file")"
                    echo "   Package was installed from trusted repository, but signature verification failed"
                fi
            fi
        done
    else
        echo "ℹ️  Package files not found in cache, skipping signature verification"
        log_verbose "No .deb files found in /var/cache/apt/archives/"
    fi
else
    echo "ℹ️  debsig-verify not available, skipping package signature verification"
    log_verbose "debsig-verify command not found on system"
fi

# Step 7: Verify installations
log_step "✅ Verifying installations..." "Checking if 1Password app and CLI are properly installed"

if command -v 1password &> /dev/null; then
    echo "✓ 1Password desktop app installed successfully"
    log_verbose "1password command found in PATH"
else
    echo "⚠️  Warning: 1Password desktop app may not be properly installed"
    log_verbose "1password command not found in PATH"
fi

if command -v op &> /dev/null; then
    echo "✓ 1Password CLI (op) installed successfully"
    local op_version=$(op --version 2>/dev/null || echo "unknown")
    echo "   Version: $op_version"
    log_verbose "op command found in PATH with version: $op_version"
else
    echo "❌ Error: 1Password CLI (op) installation failed"
    log_verbose "op command not found in PATH"
    exit 1
fi

echo ""
echo "🎉 Installation completed successfully!"
log_verbose "All installation steps completed without errors"
echo ""
echo "Next steps:"
echo "1. Open 1Password: Run '1password' or find it in your applications"
echo "2. Set up CLI integration: In 1Password app → Settings → Developer → Enable '1Password CLI integration'"
echo "3. Test CLI: Run 'op --help' to see available commands"
echo ""
echo "For more information, visit: https://developer.1password.com/docs/cli/get-started/"
log_verbose "Installation script finished successfully"
