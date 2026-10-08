#!/usr/bin/env bash
# @desc   Shell: alias library -> /etc/profile.d/.alias, system bashrc hook, git defaults
# @order  20
#
# System-wide, for every user: the runtime library (configs/alias) goes to ALIAS_DIR,
# and one managed block in the system bashrc (SYS_BASHRC: /etc/bash.bashrc or
# /etc/bashrc) loads it into interactive shells and records where this checkout is,
# for the `dotfiles` command. Users' own ~/.bashrc files are not touched.
# A redeploy keeps the host's .bash_local and removes modules the repo no longer has.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

# --- 1. The library -----------------------------------------------------------------
df_install_dir -m 0644 -v df_check_bash -p '.bash_*' -k '.bash_local' \
    "$DOTFILES_ROOT/configs/alias" "$ALIAS_DIR"

# --- 2. The hook ----------------------------------------------------------------------
# /etc/profile.d only auto-loads *.sh, and .alias is a directory -- hence the bashrc
# block. Interactive bash only: scripts source the library explicitly.
hook=$(cat <<EOF
export DOTFILES_ROOT="${DOTFILES_ROOT}"
if [ -n "\${BASH_VERSION:-}" ] && [ -f "${ALIAS_DIR}/.bash_aliases" ]; then
    case \$- in *i*) . "${ALIAS_DIR}/.bash_aliases" ;; esac
fi
EOF
)
# Loaders written before the managed block existed: system/aliases.sh's sentinel block
# and ensure_alias_hook's one-liner. Left in place they would load the library twice.
remove_legacy_loader() {
    local target new
    target=$(df_path "$SYS_BASHRC")
    [[ -f "$target" ]] || return 0
    new=$(mktemp)
    awk -v dir="$ALIAS_DIR" '
        /^# --- Shell alias modules/ { skip = 1 }
        skip { if ($0 == "PROMPT_COMMAND=build_ps1") skip = 0; next }
        $0 == "[ -f " dir "/.bash_aliases ] && source " dir "/.bash_aliases" { next }
        { print }
    ' "$target" > "$new"
    if cmp -s "$new" "$target"; then
        rm -f "$new"
        return 0
    fi
    # An unterminated legacy block would have eaten the rest of the file
    if grep -q '^# --- Shell alias modules' "$target" && ! grep -qx 'PROMPT_COMMAND=build_ps1' "$target"; then
        rm -f "$new"
        die "${SYS_BASHRC}: legacy alias block has no 'PROMPT_COMMAND=build_ps1' end line -- remove it by hand"
    fi
    if (( DF_DRY_RUN )); then
        log_info "[dry-run] remove the legacy alias loader from ${SYS_BASHRC}"
    else
        df_backup "$target"
        cat "$new" > "$target"
        log_ok "removed    legacy alias loader from ${SYS_BASHRC}"
    fi
    rm -f "$new"
}

# Markers first: a refused deploy must leave the file exactly as it found it. Then the
# legacy loader, so the block lands on a file already free of it.
df_block_check "$SYS_BASHRC" hook
remove_legacy_loader
df_block "$SYS_BASHRC" hook "$hook"

# --- 3. Git defaults --------------------------------------------------------------------
# System level (/etc/gitconfig), so every user gets them and anyone's ~/.gitconfig --
# name, email -- still wins. A managed block: whatever else the file holds stays.
df_block /etc/gitconfig defaults "$(cat "$DOTFILES_ROOT/configs/gitconfig")"

log_ok "Shell library deployed -- open a new shell, or: source ${SYS_BASHRC}"
