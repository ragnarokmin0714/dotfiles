#!/usr/bin/env bash
# =============================================================================
# system/bashrc.sh — Shell Configuration Deployment
# =============================================================================
# Deploys the .bashrc template from configs/ to the deploy user's home
# directory. Backs up any existing .bashrc before overwriting.
#
# Supports both bash and zsh (controlled by SHELL_TYPE in lib/env.sh).
#
# REQUIRES: Run as root (sudo) so we can write to /home/<user>/
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

# Determine the target shell config file path
if [[ "$SHELL_TYPE" == "zsh" ]]; then
  TARGET_RC="$DEPLOY_HOME/.zshrc"
  SOURCE_RC="$CONFIGS_DIR/.zshrc"
else
  TARGET_RC="$DEPLOY_HOME/.bashrc"
  SOURCE_RC="$CONFIGS_DIR/.bashrc"
fi

# Verify the source template exists
if [[ ! -f "$SOURCE_RC" ]]; then
  log_error "Shell config template not found: $SOURCE_RC"
fi

# Back up the existing config file if it exists
if [[ -f "$TARGET_RC" ]]; then
  BACKUP="$TARGET_RC.bak.$(date +%Y%m%d_%H%M%S)"
  cp "$TARGET_RC" "$BACKUP"
  log_info "Existing $TARGET_RC backed up to: $BACKUP"
fi

# Copy the .bashrc template to the user's home directory
cp "$SOURCE_RC" "$TARGET_RC"
chown "$DEPLOY_USER:$DEPLOY_USER" "$TARGET_RC"

log_success "Shell config deployed: $TARGET_RC"

# --- Deploy alias modules to ~/.alias/ ---
ALIAS_SOURCE="$CONFIGS_DIR/alias"
ALIAS_TARGET="$DEPLOY_HOME/.alias"

if [[ -d "$ALIAS_SOURCE" ]]; then
  log_info "Deploying alias modules to $ALIAS_TARGET..."

  # Back up existing .alias directory if present
  if [[ -d "$ALIAS_TARGET" ]]; then
    ALIAS_BACKUP="${ALIAS_TARGET}.bak.$(date +%Y%m%d_%H%M%S)"
    cp -r "$ALIAS_TARGET" "$ALIAS_BACKUP"
    log_info "Existing $ALIAS_TARGET backed up to: $ALIAS_BACKUP"
  fi

  mkdir -p "$ALIAS_TARGET"
  cp -r "$ALIAS_SOURCE/." "$ALIAS_TARGET/"
  chown -R "$DEPLOY_USER:$DEPLOY_USER" "$ALIAS_TARGET"
  chmod -R 644 "$ALIAS_TARGET"/.bash_*

  log_success "Alias modules deployed: $ALIAS_TARGET"
else
  log_warn "Alias source directory not found: $ALIAS_SOURCE — skipping."
fi

log_info "Run 'source $TARGET_RC' or open a new terminal to apply changes."
