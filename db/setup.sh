#!/usr/bin/env bash
# =============================================================================
# db/setup.sh — Database Module Entry Point
# =============================================================================
# Installs and configures database services.
# By default installs PostgreSQL, MySQL, and Redis.
# Comment out any line below to skip that database.
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_section "Database Setup"

log_info "Step 1/3 — Installing PostgreSQL $POSTGRES_VERSION..."
bash "$DOTFILES_ROOT/db/postgres.sh"

log_info "Step 2/3 — Installing MySQL $MYSQL_VERSION..."
bash "$DOTFILES_ROOT/db/mysql.sh"

log_info "Step 3/3 — Installing Redis..."
bash "$DOTFILES_ROOT/db/redis.sh"

log_success "Database setup complete."
