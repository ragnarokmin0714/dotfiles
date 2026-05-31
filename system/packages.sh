#!/usr/bin/env bash
# =============================================================================
# system/packages.sh — Base Package Installation
# =============================================================================
# Installs essential Linux packages required by all other modules.
# Supports Ubuntu/Debian (apt) and Rocky Linux / RHEL / Fedora (dnf).
# This script must run before any other module.
#
# REQUIRES: sudo / root privileges
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_info "Detected distro family: $DISTRO_FAMILY"

# =============================================================================
# Ubuntu / Debian — apt
# =============================================================================
if [[ "$DISTRO_FAMILY" == "debian" ]]; then

  BASE_PACKAGES=(
    curl            # HTTP client — required by nvm, docker install scripts
    wget            # Alternative HTTP downloader
    git             # Version control
    vim             # Text editor
    htop            # Interactive process viewer
    unzip           # Archive extraction
    build-essential # GCC, make — required for compiling native modules
    ca-certificates # SSL certificate bundle
    gnupg           # GPG — required for verifying apt repository keys
    ufw             # Uncomplicated Firewall
    net-tools       # Includes ifconfig, netstat
    tree            # Directory tree viewer
    jq              # JSON processor
  )

  log_info "Updating apt package index..."
  apt-get update -qq

  log_info "Installing ${#BASE_PACKAGES[@]} base packages..."
  apt-get install -y --no-install-recommends "${BASE_PACKAGES[@]}"

# =============================================================================
# Rocky Linux / RHEL / Fedora — dnf
# =============================================================================
elif [[ "$DISTRO_FAMILY" == "rhel" ]]; then

  BASE_PACKAGES=(
    curl            # HTTP client
    wget            # Alternative HTTP downloader
    git             # Version control
    vim             # Text editor
    htop            # Interactive process viewer
    unzip           # Archive extraction
    gcc             # C compiler (part of Development Tools)
    gcc-c++         # C++ compiler
    make            # Build tool
    ca-certificates # SSL certificate bundle
    gnupg2          # GPG — required for verifying repo keys
    firewalld       # Firewall daemon (replaces ufw on RHEL family)
    net-tools       # Includes ifconfig, netstat
    tree            # Directory tree viewer
    jq              # JSON processor
  )

  log_info "Updating dnf package index..."
  dnf makecache -q

  log_info "Installing ${#BASE_PACKAGES[@]} base packages..."
  dnf install -y "${BASE_PACKAGES[@]}"

  # Enable EPEL for additional packages used by db and project modules
  if ! rpm -q epel-release &>/dev/null; then
    log_info "Enabling EPEL repository..."
    dnf install -y epel-release
  fi

# =============================================================================
# Unknown distro
# =============================================================================
else
  log_error "Unsupported distro family: '$DISTRO_FAMILY'. Expected apt or dnf."
fi

log_success "Base packages installed successfully."
