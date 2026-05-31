#!/usr/bin/env bash
# =============================================================================
# system/sudo.sh — Sudo Permission Configuration
# =============================================================================
# Grants the deploy user passwordless sudo access for specific commands.
# Uses a drop-in sudoers file under /etc/sudoers.d/ to avoid editing
# the main /etc/sudoers directly (safer, easier to revert).
#
# REQUIRES: Must be run as root (via sudo)
# SECURITY NOTE:
#   Passwordless sudo for specific commands is acceptable for automation.
#   Do NOT grant NOPASSWD: ALL in production environments.
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

SUDOERS_FILE="/etc/sudoers.d/99-dotfiles-$DEPLOY_USER"
SUDOERS_TEMPLATE="$CONFIGS_DIR/sudoers.d/99-dotfiles"

# Verify we are running as root
if [[ "$EUID" -ne 0 ]]; then
  log_error "sudo.sh must be run as root. Use: sudo bash $0"
fi

log_info "Configuring sudoers for user: $DEPLOY_USER"

# Copy the template and substitute the username placeholder
sed "s/__USER__/$DEPLOY_USER/g" "$SUDOERS_TEMPLATE" > "$SUDOERS_FILE"

# Validate the generated sudoers file before activating it.
# visudo -c will catch syntax errors that could lock you out of sudo.
if visudo -c -f "$SUDOERS_FILE"; then
  chmod 0440 "$SUDOERS_FILE"
  log_success "Sudoers file deployed: $SUDOERS_FILE"
else
  rm -f "$SUDOERS_FILE"
  log_error "Generated sudoers file has syntax errors — removed. Check $SUDOERS_TEMPLATE"
fi
