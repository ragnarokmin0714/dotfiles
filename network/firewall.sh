#!/usr/bin/env bash
# =============================================================================
# network/firewall.sh — Firewall Configuration
# =============================================================================
# Ubuntu / Debian  → ufw (Uncomplicated Firewall)
# Rocky / RHEL     → firewalld
#
# CONFIGURATION (set in lib/env.sh):
#   FIREWALL_ALLOW_PORTS — Array of TCP ports to allow inbound
#                          e.g. (22 80 443 3000 5432)
#
# REQUIRES: sudo / root privileges
# WARNING: Ensure port 22 (SSH) is in FIREWALL_ALLOW_PORTS or you will be
#          locked out of the machine remotely.
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_info "Distro family: $DISTRO_FAMILY"

# Safety check: port 22 must be in the allow list to prevent SSH lockout
if [[ ! " ${FIREWALL_ALLOW_PORTS[*]} " =~ " 22 " ]]; then
  log_error "Port 22 (SSH) is not in FIREWALL_ALLOW_PORTS. Aborting to prevent SSH lockout."
fi

# =============================================================================
# Ubuntu / Debian — ufw
# =============================================================================
if [[ "$DISTRO_FAMILY" == "debian" ]]; then

  log_info "Configuring ufw firewall..."

  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing

  for port in "${FIREWALL_ALLOW_PORTS[@]}"; do
    ufw allow "$port/tcp"
    log_info "  Opened port: $port/tcp"
  done

  ufw --force enable

  log_info "Current ufw status:"
  ufw status verbose

# =============================================================================
# Rocky Linux / RHEL — firewalld
# =============================================================================
elif [[ "$DISTRO_FAMILY" == "rhel" ]]; then

  log_info "Configuring firewalld..."

  systemctl enable --now firewalld
  firewall-cmd --set-default-zone=public

  # Remove previously added custom ports from permanent config
  for existing_port in $(firewall-cmd --permanent --list-ports 2>/dev/null); do
    firewall-cmd --permanent --remove-port="$existing_port" &>/dev/null || true
  done

  for port in "${FIREWALL_ALLOW_PORTS[@]}"; do
    firewall-cmd --permanent --add-port="${port}/tcp"
    log_info "  Opened port: $port/tcp"
  done

  firewall-cmd --reload

  log_info "Current firewalld open ports:"
  firewall-cmd --list-ports

else
  log_error "Unsupported distro family: '$DISTRO_FAMILY'. Cannot configure firewall."
fi

log_success "Firewall configured. Open ports: ${FIREWALL_ALLOW_PORTS[*]}"
