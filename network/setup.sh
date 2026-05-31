#!/usr/bin/env bash
# =============================================================================
# network/setup.sh — Network Module Entry Point
# =============================================================================
# Orchestrates all network configuration steps in order:
#   1. Configure static IP (optional, controlled by STATIC_IP in env.sh)
#   2. Configure DNS resolvers
#   3. Configure ufw firewall rules
#   4. Deploy HTTPS via Nginx + OpenSSL self-signed certificate
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_section "Network Setup"

# Step 1: Static IP — only runs if STATIC_IP is set in env.sh
if [[ -n "${STATIC_IP:-}" ]]; then
  log_info "Step 1/4 — Configuring static IP: $STATIC_IP"
  bash "$DOTFILES_ROOT/network/static-ip.sh"
else
  log_info "Step 1/4 — STATIC_IP not set in env.sh, skipping static IP configuration."
fi

log_info "Step 2/4 — Configuring DNS..."
bash "$DOTFILES_ROOT/network/dns.sh"

log_info "Step 3/4 — Configuring firewall..."
bash "$DOTFILES_ROOT/network/firewall.sh"

log_info "Step 4/4 — Deploying HTTPS (Nginx + OpenSSL)..."
bash "$DOTFILES_ROOT/network/https.sh"

log_success "Network setup complete."
