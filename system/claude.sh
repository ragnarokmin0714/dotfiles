#!/usr/bin/env bash
# =============================================================================
# system/claude.sh — Deploy Claude Code Global Config
# =============================================================================
# Deploys configs/claude/ to the deploy user's ~/.claude/ directory.
#
# USAGE (standalone):
#   sudo bash system/claude.sh
#
# CALLED BY:
#   lib/menu.sh  (menu option 8)
#   _run_all
#
# DEPLOYS (configs/claude/ → ~/.claude/):
#   agents/         → cross-project agent roles (builder, reviewer, tester, ...)
#   commands/       → personal slash commands (/gitmsg, /jsdoc, /why, ...)
#   skills/         → reusable skills (shadcn-refactor, ...)
#   hooks/          → enforcement hooks (block-bash-bypass.sh, ...)
#   settings.json   → personal preferences (backed up before overwrite)
#   CLAUDE.md       → global personal rules (e.g. git commit convention)
#
# NOT DEPLOYED:
#   settings.local.example.json  → repo-side template only; copy manually per
#                                  project as .claude/settings.local.json
#
# SAFETY:
#   ~/.claude/ holds live state (sessions, projects, file-history). This
#   script only replaces the six items above and never touches anything
#   else. Existing versions are backed up to ~/.claude/backups/ first.
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_section "Claude Code — Deploy ~/.claude/ config"

CLAUDE_SOURCE="$CONFIGS_DIR/claude"
CLAUDE_TARGET="$DEPLOY_HOME/.claude"

# --- Validate source ---
if [[ ! -d "$CLAUDE_SOURCE" ]]; then
  log_error "Claude config source directory not found: $CLAUDE_SOURCE"
fi

mkdir -p "$CLAUDE_TARGET"

# --- Backup existing deployed items (only those this script manages) ---
BACKUP_DIR="$CLAUDE_TARGET/backups/config.bak.$(date +%Y%m%d_%H%M%S)"
BACKED_UP=false
for item in agents commands skills hooks settings.json CLAUDE.md; do
  if [[ -e "$CLAUDE_TARGET/$item" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp -r "$CLAUDE_TARGET/$item" "$BACKUP_DIR/"
    BACKED_UP=true
  fi
done
if [[ "$BACKED_UP" == true ]]; then
  log_info "Existing config backed up to: $BACKUP_DIR"
  # Prune old backups — keep only the 3 most recent
  find "$CLAUDE_TARGET/backups" -maxdepth 1 -name "config.bak.*" -type d \
    | sort -r | tail -n +4 | xargs -r rm -rf
  log_info "Old backups pruned (keeping 3 most recent)."
fi

# --- Deploy: replace managed items, leave everything else untouched ---
for dir in agents commands skills hooks; do
  if [[ -d "$CLAUDE_SOURCE/$dir" ]]; then
    rm -rf "${CLAUDE_TARGET:?}/$dir"
    cp -r "$CLAUDE_SOURCE/$dir" "$CLAUDE_TARGET/$dir"
    log_info "Deployed: $dir/"
  fi
done

for file in settings.json CLAUDE.md; do
  if [[ -f "$CLAUDE_SOURCE/$file" ]]; then
    cp "$CLAUDE_SOURCE/$file" "$CLAUDE_TARGET/$file"
    log_info "Deployed: $file"
  fi
done

# --- Permissions ---
chown -R "$DEPLOY_USER:$DEPLOY_USER" \
  "$CLAUDE_TARGET/agents" "$CLAUDE_TARGET/commands" "$CLAUDE_TARGET/skills" \
  "$CLAUDE_TARGET/hooks" "$CLAUDE_TARGET/settings.json" \
  "$CLAUDE_TARGET/CLAUDE.md" 2>/dev/null || true
[[ -d "$BACKUP_DIR" ]] && chown -R "$DEPLOY_USER:$DEPLOY_USER" "$BACKUP_DIR"
chmod 755 "$CLAUDE_TARGET"/hooks/*.sh 2>/dev/null || true

log_success "Claude Code config deployed to: $CLAUDE_TARGET"
log_info "Restart Claude Code (or start a new session) to pick up the changes."
