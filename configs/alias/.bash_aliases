#!/usr/bin/env bash
# @file .bash_aliases
# @brief Entry point of the runtime library: sources every module in order.
# @description
#   Three consumers source this one file:
#     - interactive bash, through the dotfiles hook in the system bashrc (SYS_BASHRC);
#     - root's maintenance scripts in /usr/local/sbin, under cron;
#     - the deploy framework (lib/core.sh), from the repo copy.
#   It resolves its own directory, so the repo copy and the deployed copy
#   (/etc/profile.d/.alias) behave the same.
#
#   Load order:
#     .bash_local  optional per-host settings, loaded FIRST so every ${VAR:-default}
#                  below picks them up (see .bash_local.example). Never deployed over.
#     .bash_env    platform globals, paths, defaults, STYLE, log_*
#     .bash_ui     menus (radioselect / multiselect), confirm, ask
#     the rest     feature modules; they may use anything above
#
#   To add a module: create .bash_<name> and add <name> to ALIAS_MODULES.

_ALIAS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIAS_MODULES=(env ui prompt functions pkg disk git nginx mongo nvm)

# shellcheck disable=SC1091
[[ -f "$_ALIAS_DIR/.bash_local" ]] && source "$_ALIAS_DIR/.bash_local"
for _alias_module in "${ALIAS_MODULES[@]}"; do
    if [[ -f "$_ALIAS_DIR/.bash_${_alias_module}" ]]; then
        # shellcheck disable=SC1090
        source "$_ALIAS_DIR/.bash_${_alias_module}"
    else
        echo "dotfiles: missing module ${_ALIAS_DIR}/.bash_${_alias_module}" >&2
    fi
done
unset _alias_module

if [[ $- == *i* ]]; then prompt_enable; fi

# Option letters across these modules: a letter keeps one meaning everywhere, so habits
# carry over between commands. Check this list before adding an option.
#   -h, --help      print usage
#   -n, --dry-run   show what would happen, change nothing
#   -y, --yes       answer yes to every confirmation
#   -p, --package   package name, takes a value              (pkg_installed / ensure / remove)
#   -m, --manager   package manager, takes a value           (pkg_*)
#   -g, --global    global install                           (pkg_*)
#   -s, --search    search instead of the exact name         (pkg_*)
#   -b, --base      base branch, takes a value               (git_switch_and_pull)
#   -r, --remote    git remote, takes a value                (git_push_current_branch)
#   -d, --dir       directory, takes a value                 (run_project)
#   -l, --list      list only                                (tz)
#   -o, --optional  include the optional set                 (sys_toolkit)
# Older exceptions, kept so habits still work: pkg_unused -s is --min-size,
# sys_toolkit -m and nvm_upgrade -m open a menu, git_amend -m is --message.
# Don't add new ones.
