#!/usr/bin/env bash
# =============================================================================
# system/setup.sh — System Module Entry Point
# =============================================================================
# Orchestrates all system-level configuration steps in order:
#   1. Install base apt packages
#   2. Configure sudo permissions
#   3. Deploy shell configuration (.bashrc / .zshrc)
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_section "System Setup"

log_info "Step 1/3 — Installing base packages..."
bash "$DOTFILES_ROOT/system/packages.sh"

log_info "Step 2/3 — Configuring sudo permissions..."
bash "$DOTFILES_ROOT/system/sudo.sh"

log_info "Step 3/3 — Deploying shell configuration..."
bash "$DOTFILES_ROOT/system/bashrc.sh"

log_success "System setup complete."
