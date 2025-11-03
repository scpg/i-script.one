# 1Password Installation for Linux

A secure, comprehensive installation script for 1Password desktop app and CLI on Linux (Debian/Ubuntu).

## 🚀 Quick Start

```bash
# Make the script executable
chmod +x 1password/install-1password.sh

# Run the installation (normal mode)
./1password/install-1password.sh

# Run with detailed output (verbose mode)
./1password/install-1password.sh --verbose

# Show help
./1password/install-1password.sh --help
```

## 📋 Features

### ✅ **Complete Installation**
- **1Password Desktop App**: Full GUI application
- **1Password CLI (`op`)**: Command-line interface for automation
- **Automatic Updates**: Configures official repository for future updates

### 🔐 **Security Features**
- **GPG Key Verification**: Validates 1Password's signing key fingerprint
- **Connectivity Checks**: Ensures all sources are reachable before download
- **Package Signature Verification**: Uses `debsig-verify` when available
- **Secure Key Handling**: Uses temporary keyrings for verification

### 🔧 **User Experience**
- **Verbose Mode**: Detailed logging with `-v` or `--verbose`
- **Help Documentation**: Built-in help with `-h` or `--help`
- **Error Handling**: Clear error messages and troubleshooting guidance
- **Progress Indicators**: Visual feedback throughout installation

## 🛠️ Usage Options

### Command Line Arguments

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show detailed output for each step |
| `-h, --help` | Display help message and usage information |

### Examples

#### Basic Installation
```bash
./1password/install-1password.sh
```

#### Verbose Installation (for debugging/transparency)
```bash
./1password/install-1password.sh --verbose
```

#### Help Information
```bash
./1password/install-1password.sh --help
```

## 🔍 What the Script Does

1. **System Compatibility Check**: Verifies Debian/Ubuntu system
2. **Network Connectivity Tests**: Ensures all 1Password servers are reachable
3. **GPG Key Download & Verification**: Downloads and validates 1Password's signing key
4. **Repository Setup**: Adds official 1Password repository
5. **Package Verification Policy**: Configures debsig-verify for automatic verification
6. **Package Installation**: Installs both desktop app and CLI
7. **Signature Verification**: Verifies installed package signatures
8. **Installation Verification**: Confirms successful installation

## 🔐 Security Validation

The script performs multiple security checks:

- **GPG Fingerprint Verification**: `3FEF9748469ADBE15DA7CA80AC2D62742012EA22`
- **HTTPS Downloads**: All downloads use secure connections
- **Temporary File Cleanup**: Secure handling of temporary files
- **Package Signature Checks**: Validates .deb package authenticity

## 📚 Post-Installation

After successful installation:

1. **Open 1Password**: Run `1password` or find it in applications
2. **Enable CLI Integration**: 
   - Open 1Password app
   - Go to Settings → Developer
   - Enable "1Password CLI integration"
3. **Test CLI**: Run `op --help` to verify CLI functionality

## 🐛 Troubleshooting

### Verbose Mode for Debugging
Use verbose mode to see detailed execution:
```bash
./1password/install-1password.sh --verbose
```

### Common Issues
- **Network connectivity**: Script checks all URLs before proceeding
- **GPG verification**: All keys are validated against expected fingerprints
- **Permissions**: Script will prompt for sudo when needed

## 📖 Documentation Sources

* [1Password Linux Installation](https://support.1password.com/install-linux/#debian-or-ubuntu)
* [1Password CLI Getting Started](https://developer.1password.com/docs/cli/get-started/)
* [1Password Developer Documentation](https://developer.1password.com/)

## 🔧 System Requirements

- **OS**: Debian, Ubuntu, or derivatives
- **Architecture**: amd64, arm64 (automatically detected)
- **Network**: Internet connection for downloads
- **Permissions**: sudo access for system installation

## 📝 Script Features

### Logging Levels
- **Normal Mode**: Clean, user-friendly output
- **Verbose Mode**: Detailed technical information
- **Error Context**: Comprehensive error reporting

### Safety Features
- **Exit on Error**: Script stops immediately on any failure
- **Connectivity Validation**: Pre-flight checks for all downloads
- **Cleanup**: Automatic cleanup of temporary files
- **Verification**: Multiple layers of security validation

---

**Note**: This script follows official 1Password installation documentation and implements enterprise-level security practices for safe, reliable installation.