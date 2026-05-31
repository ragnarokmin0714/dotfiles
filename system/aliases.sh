#!/usr/bin/env bash
# =============================================================================
# system/aliases.sh — Deploy Shell Alias Modules
# =============================================================================
# Deploys configs/alias/ files to ~/.alias/ and ensures /etc/bashrc sources them.
#
# USAGE (standalone):
#   sudo bash system/aliases.sh
#
# CALLED BY:
#   lib/menu.sh  (menu option 6)
#   system/setup.sh (via _run_all)
#
# DEPLOYS:
#   configs/alias/.bash_env        → ANSI STYLE map, git_prompt(), build_ps1()
#   configs/alias/.bash_git        → Git aliases + interactive branch functions
#   configs/alias/.bash_functions  → System/disk/project utilities
#   configs/alias/.bash_aliases    → Entry point that sources the above 3
#
# BASHRC UPDATE (/etc/bashrc):
#   Removes any existing alias-loader block, then re-inserts the current one.
#   This ensures the block is always up-to-date (idempotent, safe to re-run).
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_section "Shell Aliases — Deploy ~/.alias/"

ALIAS_SOURCE="$CONFIGS_DIR/alias"
ALIAS_TARGET="$DEPLOY_HOME/.alias"

# Detect system-wide bashrc path — differs by distro:
#   Rocky Linux / RHEL / Fedora  → /etc/bashrc
#   Ubuntu / Debian              → /etc/bash.bashrc
if [[ -f /etc/bashrc ]]; then
  SYSTEM_BASHRC="/etc/bashrc"
elif [[ -f /etc/bash.bashrc ]]; then
  SYSTEM_BASHRC="/etc/bash.bashrc"
else
  SYSTEM_BASHRC=""
fi

# --- Validate source ---
if [[ ! -d "$ALIAS_SOURCE" ]]; then
  log_error "Alias source directory not found: $ALIAS_SOURCE"
fi

# --- Backup existing .alias if present ---
if [[ -L "$ALIAS_TARGET" ]]; then
  # It's a symlink — remove the symlink only, do not touch the target
  log_warn "$ALIAS_TARGET is a symlink — removing symlink before deploying real directory."
  rm "$ALIAS_TARGET"
elif [[ -d "$ALIAS_TARGET" ]]; then
  # It's a real directory — back it up with a timestamp
  ALIAS_BACKUP="${ALIAS_TARGET}.bak.$(date +%Y%m%d_%H%M%S)"
  cp -r "$ALIAS_TARGET" "$ALIAS_BACKUP"
  log_info "Existing $ALIAS_TARGET backed up to: $ALIAS_BACKUP"

  # Prune old backups — keep only the 3 most recent
  find "$(dirname "$ALIAS_TARGET")" -maxdepth 1 -name ".alias.bak.*" -type d \
    | sort -r | tail -n +4 | xargs -r rm -rf
  log_info "Old backups pruned (keeping 3 most recent)."
fi

# --- Create target and copy files ---
mkdir -p "$ALIAS_TARGET"
cp -r "$ALIAS_SOURCE/." "$ALIAS_TARGET/"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$ALIAS_TARGET"
chmod 644 "$ALIAS_TARGET"/.bash_* 2>/dev/null || true

log_success "Alias files deployed to: $ALIAS_TARGET"

# --- Update /etc/bashrc ---
# The block is delimited by sentinel comments so it can be reliably found
# and removed before re-insertion, making this step safe to run multiple times.

BLOCK_START='# --- Shell alias modules (~/.alias/) ---'
BLOCK_END='PROMPT_COMMAND=build_ps1'

read -r -d '' ALIAS_BLOCK << 'EOF'
# --- Shell alias modules (~/.alias/) ---
# Sources .bash_env (STYLE/git_prompt/build_ps1), .bash_git, .bash_functions
[ -f ~/.alias/.bash_aliases ] && source ~/.alias/.bash_aliases

# Rebuild the custom PS1 before each prompt
PROMPT_COMMAND=build_ps1
EOF

if [[ -n "$SYSTEM_BASHRC" ]]; then
  # Remove existing block (from BLOCK_START line through BLOCK_END line, inclusive)
  if grep -qF "$BLOCK_START" "$SYSTEM_BASHRC"; then
    # Use sed to delete from the start sentinel to the end sentinel line
    sed -i "/^# --- Shell alias modules/,/^PROMPT_COMMAND=build_ps1/d" "$SYSTEM_BASHRC"
    # Also remove any blank line immediately before the block that we may have left behind
    # (trim trailing blank lines at end of file)
    sed -i -e '/^[[:space:]]*$/{ N; /^\n$/d; }' "$SYSTEM_BASHRC" 2>/dev/null || true
    log_info "Removed existing alias-loader block from $SYSTEM_BASHRC"
  fi

  # Append current block
  printf '\n%s\n' "$ALIAS_BLOCK" >> "$SYSTEM_BASHRC"
  log_success "Alias-loader block written to: $SYSTEM_BASHRC"
else
  log_warn "No supported system bashrc found (/etc/bashrc or /etc/bash.bashrc) — skipping system-wide update."
  log_info "Add the following block manually to your shell init file:"
  printf '%s\n' "$ALIAS_BLOCK"
fi

log_success "Shell aliases setup complete."
log_info "Apply changes in the current terminal:"
log_info "  source ${SYSTEM_BASHRC:-/etc/bashrc}"
log_info "After that, use 'rl' to reload anytime."
