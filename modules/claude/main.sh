#!/usr/bin/env bash
# @desc   Claude Code: agents, commands, skills, hooks, settings -> ~/.claude of DEPLOY_USER
# @order  50
#
# User-level: run it as the user, or with sudo for DEPLOY_USER. ~/.claude also holds
# live state (sessions, projects, history) and skills/agents from plugins and syncs, so
# the four directories are shared: each keeps a .dotfiles-manifest of what dotfiles put
# there, and only those files are ever removed when the repo drops them -- everything
# else in ~/.claude is left alone. Replaced files are backed up first (DF_BACKUP_DIR).
# Not deployed:
# settings.local.example.json and CLAUDE.example.md -- templates to copy by hand.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start

if (( EUID != 0 )) && [[ "$(id -un)" != "$DEPLOY_USER" ]] && ! df_is_dry; then
    die "Run as ${DEPLOY_USER}, or with sudo"
fi

src="$DOTFILES_ROOT/configs/claude"
dst="$DEPLOY_HOME/.claude"
owner="${DEPLOY_USER}:$(id -gn "$DEPLOY_USER" 2>/dev/null || echo "$DEPLOY_USER")"

for dir in agents commands skills; do
    df_install_dir -M -o "$owner" "$src/$dir" "$dst/$dir"
done
df_install_dir -M -m 0755 -o "$owner" -v df_check_bash "$src/hooks" "$dst/hooks"
df_install -o "$owner" "$src/settings.json" "$dst/settings.json"
df_install -o "$owner" "$src/CLAUDE.md" "$dst/CLAUDE.md"

# install -D creates missing parent directories as the caller: under sudo that is
# root, inside the user's home. Hand them back.
if (( EUID == 0 )) && ! df_is_dry; then
    chown "$owner" "$dst"
    chown -R "$owner" "$dst/agents" "$dst/commands" "$dst/skills" "$dst/hooks"
fi
log_ok "Claude Code config deployed to ${dst} -- start a new session to pick it up"
