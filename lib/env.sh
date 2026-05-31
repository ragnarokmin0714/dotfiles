#!/usr/bin/env bash
# =============================================================================
# lib/env.sh — Global Environment Constants
# =============================================================================
# This file defines all global variables shared across every module script.
# Every script must source this file first:
#
#   source "$DOTFILES_ROOT/lib/env.sh"
#
# HOW TO CUSTOMIZE:
#   Edit the values below to match your environment before running install.sh.
#   Never hardcode these values inside individual module scripts.
# =============================================================================

# -----------------------------------------------------------------------------
# Dotfiles root path (auto-resolved, do not change)
# -----------------------------------------------------------------------------
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------
# Directory paths
# -----------------------------------------------------------------------------
LOG_DIR="$DOTFILES_ROOT/logs"
CONFIGS_DIR="$DOTFILES_ROOT/configs"

# -----------------------------------------------------------------------------
# System user
# -----------------------------------------------------------------------------
DEPLOY_USER="${SUDO_USER:-$USER}"          # The non-root user to configure for
DEPLOY_HOME="/home/$DEPLOY_USER"

# -----------------------------------------------------------------------------
# Network configuration
# -----------------------------------------------------------------------------
NETWORK_INTERFACE="eth0"                   # Network interface name (use `ip a` to check)
STATIC_IP="192.168.1.100"                  # Static IP address (leave empty to skip)
GATEWAY="192.168.1.1"                      # Default gateway
SUBNET_MASK="24"                           # CIDR subnet mask (e.g. 24 = 255.255.255.0)
PRIMARY_DNS="8.8.8.8"                      # Primary DNS server
SECONDARY_DNS="8.8.4.4"                    # Secondary DNS server

# -----------------------------------------------------------------------------
# Firewall configuration
# -----------------------------------------------------------------------------
FIREWALL_ALLOW_PORTS=(22 80 443 3000 5432) # Ports to open in ufw

# -----------------------------------------------------------------------------
# Database configuration
# -----------------------------------------------------------------------------
DB_ROOT_PASSWORD="changeme"                # Root/admin DB password — CHANGE THIS
DB_USER="appuser"                          # Application DB user
DB_PASSWORD="changeme"                     # Application DB user password — CHANGE THIS
DB_NAME="appdb"                            # Default database name
POSTGRES_VERSION="16"                      # PostgreSQL version to install
MYSQL_VERSION="8.0"                        # MySQL version to install
REDIS_PORT=6379                            # Redis listen port

# -----------------------------------------------------------------------------
# Node.js / Frontend tooling
# -----------------------------------------------------------------------------
NODE_VERSION="20"                          # Node.js LTS version (via nvm)
PNPM_VERSION="10"                          # pnpm version to install globally

# -----------------------------------------------------------------------------
# Docker configuration
# -----------------------------------------------------------------------------
DOCKER_COMPOSE_VERSION="2"                 # Docker Compose plugin version (v2 = plugin)

# -----------------------------------------------------------------------------
# ISO build configuration
# -----------------------------------------------------------------------------
ISO_SOURCE="/dev/null"                     # Path to source ISO file or block device
ISO_OUTPUT_DIR="$HOME/iso-build"           # Directory to write the built ISO
ISO_LABEL="CUSTOM-LINUX"                   # Volume label for the built ISO

# -----------------------------------------------------------------------------
# Shell configuration
# -----------------------------------------------------------------------------
SHELL_TYPE="bash"                          # Target shell: bash | zsh
BASHRC_SOURCE="$CONFIGS_DIR/.bashrc"       # Path to the .bashrc template to deploy

# -----------------------------------------------------------------------------
# Distro family detection (auto-detected, do not change)
# Used by all module scripts to switch between apt/dnf code paths.
#   "debian" → Ubuntu / Debian (apt-get)
#   "rhel"   → Rocky Linux / RHEL / AlmaLinux / Fedora (dnf)
#   "unknown"→ Unsupported; scripts will warn and skip pkg-manager steps
# -----------------------------------------------------------------------------
if command -v dnf &>/dev/null; then
  DISTRO_FAMILY="rhel"
elif command -v apt-get &>/dev/null; then
  DISTRO_FAMILY="debian"
else
  DISTRO_FAMILY="unknown"
fi

# -----------------------------------------------------------------------------
# Color codes for terminal output (used by log.sh and menu.sh)
# -----------------------------------------------------------------------------
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[0;31m"
COLOR_CYAN="\033[0;36m"
COLOR_BOLD="\033[1m"
