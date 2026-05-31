#!/usr/bin/env bash
# =============================================================================
# project/setup.sh — Project Environment Module Entry Point
# =============================================================================
# Installs the full development toolchain for frontend and backend projects:
#   1. Docker + Docker Compose plugin
#   2. Node.js via nvm + pnpm
#   3. Backend tooling (Python, Go — customize as needed)
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_section "Project Environment Setup"

log_info "Step 1/3 — Installing Docker..."
bash "$DOTFILES_ROOT/project/docker.sh"

log_info "Step 2/3 — Installing Node.js (nvm) + pnpm..."
bash "$DOTFILES_ROOT/project/frontend.sh"

log_info "Step 3/3 — Installing backend tooling..."
bash "$DOTFILES_ROOT/project/backend.sh"

log_success "Project environment setup complete."
