#!/usr/bin/env bash
# =============================================================================
# project/frontend.sh — Node.js (via nvm) + pnpm Installation
# =============================================================================
# Installs nvm (Node Version Manager) for the deploy user, then installs
# the specified Node.js LTS version and pnpm package manager.
#
# WHY nvm: nvm allows switching Node.js versions per-project without sudo,
# which is important for developer workflows.
#
# CONFIGURATION (set in lib/env.sh):
#   NODE_VERSION — Node.js version to install, e.g. "20"
#   PNPM_VERSION — pnpm version to install globally, e.g. "10"
#
# NOTE: nvm is installed into the deploy user's home directory.
#       This script must be run as root (sudo) but nvm is installed
#       for the DEPLOY_USER via `sudo -u` invocations.
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

NVM_DIR="$DEPLOY_HOME/.nvm"
NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh"

# --- Install nvm for the deploy user ---
if [[ ! -d "$NVM_DIR" ]]; then
  log_info "Installing nvm for user '$DEPLOY_USER'..."
  sudo -u "$DEPLOY_USER" bash -c "
    export HOME=$DEPLOY_HOME
    curl -fsSL $NVM_INSTALL_URL | bash
  "
else
  log_info "nvm already installed at $NVM_DIR — skipping."
fi

# --- Install Node.js and pnpm inside nvm environment ---
log_info "Installing Node.js $NODE_VERSION and pnpm $PNPM_VERSION..."
sudo -u "$DEPLOY_USER" bash -c "
  export HOME=$DEPLOY_HOME
  export NVM_DIR=$NVM_DIR
  [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"

  # Install the specified Node.js version and set it as default
  nvm install $NODE_VERSION
  nvm alias default $NODE_VERSION
  nvm use default

  # Install pnpm globally via npm
  npm install -g pnpm@$PNPM_VERSION

  # Print versions for log verification
  echo \"Node: \$(node -v)\"
  echo \"npm:  \$(npm -v)\"
  echo \"pnpm: \$(pnpm -v)\"
"

log_success "Node.js $NODE_VERSION + pnpm $PNPM_VERSION installed for user '$DEPLOY_USER'."
