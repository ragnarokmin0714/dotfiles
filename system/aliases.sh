#!/usr/bin/env bash
# =============================================================================
# system/aliases.sh — Deploy Shell Alias Modules
# =============================================================================
# Deploys configs/alias/ to the chosen target and ensures the system bashrc
# sources the entry point.
#
# USAGE (standalone):
#   sudo bash system/aliases.sh                     # interactive target prompt
#   ALIAS_TARGET=/etc/profile.d/.alias sudo -E bash system/aliases.sh
#   ALIAS_TARGET="$HOME/.alias"        sudo -E bash system/aliases.sh
#
# CALLED BY:
#   lib/menu.sh  (menu option 7)
#   _run_all
#
# DEPLOY TARGETS (prompted; default = system-wide):
#   /etc/profile.d/.alias  → all users (root-owned, default)
#   ~/.alias               → deploy user only
#   The entry point resolves its own directory, so both targets work
#   without content changes.
#
# DEPLOYS (configs/alias/):
#   .bash_env        → ANSI STYLE map, log_* framework, git_prompt(), build_ps1()
#   .bash_git        → Git aliases + interactive branch functions
#   .bash_functions  → System/disk/datetime/project utilities
#   .bash_pkg        → Package toolkit: pkg_installed/ensure/remove, sys_toolkit
#   .bash_nginx      → Nginx service/config helpers
#   .bash_aliases    → Entry point that sources the above (in dependency order)
#
# BASHRC UPDATE (/etc/bashrc or /etc/bash.bashrc):
#   Removes any existing alias-loader block, then re-inserts the current one.
#   This ensures the block is always up-to-date (idempotent, safe to re-run).
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_section "Shell Aliases — Deploy alias modules"

ALIAS_SOURCE="$CONFIGS_DIR/alias"

# --- Select deploy target ---
# Priority: ALIAS_TARGET env var > interactive prompt > system-wide default.
TARGET_SYSTEM="/etc/profile.d/.alias"
TARGET_HOME="$DEPLOY_HOME/.alias"

if [[ -z "${ALIAS_TARGET:-}" ]]; then
  if [[ -t 0 ]]; then
    echo "Deploy target:"
    echo "  1) $TARGET_SYSTEM  (system-wide, all users) [default]"
    echo "  2) $TARGET_HOME  (deploy user only)"
    read -rp "Select [1/2]: " _choice
    case "${_choice:-1}" in
      2) ALIAS_TARGET="$TARGET_HOME" ;;
      *) ALIAS_TARGET="$TARGET_SYSTEM" ;;
    esac
  else
    ALIAS_TARGET="$TARGET_SYSTEM"
  fi
fi
log_info "Deploy target: $ALIAS_TARGET"

# --- Validate source ---
if [[ ! -d "$ALIAS_SOURCE" ]]; then
  log_error "Alias source directory not found: $ALIAS_SOURCE"
fi

# --- Backup existing target if present ---
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
if [[ "$ALIAS_TARGET" == "$TARGET_HOME" ]]; then
  # User-level deploy: files belong to the deploy user
  chown -R "$DEPLOY_USER:$DEPLOY_USER" "$ALIAS_TARGET"
else
  # System-wide deploy: root-owned, world-readable
  chown -R root:root "$ALIAS_TARGET"
fi
chmod 644 "$ALIAS_TARGET"/.bash_* 2>/dev/null || true

log_success "Alias files deployed to: $ALIAS_TARGET"

# --- Update system bashrc ---
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

# The block is delimited by sentinel comments so it can be reliably found
# and removed before re-insertion, making this step safe to run multiple times.
# For the home target, reference '~/.alias' unexpanded so each user resolves
# their own home (users without the directory silently skip it).
ALIAS_REF="$ALIAS_TARGET"
# shellcheck disable=SC2088  # literal ~ is intentional: expanded per-user at source time
[[ "$ALIAS_TARGET" == "$TARGET_HOME" ]] && ALIAS_REF='~/.alias'

ALIAS_BLOCK="$(cat << EOF
# --- Shell alias modules ($ALIAS_REF) ---
# Sources .bash_env (STYLE/log_*/git_prompt/build_ps1) and the other modules
[ -f $ALIAS_REF/.bash_aliases ] && source $ALIAS_REF/.bash_aliases

# Rebuild the custom PS1 before each prompt
PROMPT_COMMAND=build_ps1
EOF
)"

if [[ -n "$SYSTEM_BASHRC" ]]; then
  # Remove existing block (from BLOCK_START line through BLOCK_END line, inclusive)
  if grep -q '^# --- Shell alias modules' "$SYSTEM_BASHRC"; then
    # Guard: the range deletion needs the end sentinel too. Without it, sed
    # would delete from the start sentinel to end-of-file — refuse instead.
    if ! grep -q '^PROMPT_COMMAND=build_ps1' "$SYSTEM_BASHRC"; then
      log_warn "Found start sentinel but no 'PROMPT_COMMAND=build_ps1' end sentinel in $SYSTEM_BASHRC."
      log_error "Refusing to edit $SYSTEM_BASHRC (deletion would run to end-of-file). Remove or repair the old alias-loader block manually, then re-run. Note: alias files were already deployed to $ALIAS_TARGET."
    fi
    sed -i "/^# --- Shell alias modules/,/^PROMPT_COMMAND=build_ps1/d" "$SYSTEM_BASHRC"
    # Trim a stray blank line the deletion may have left behind
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
log_info "After that, use 'rs' (reload-shell) to reload anytime."
