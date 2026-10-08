#!/usr/bin/env bash
# @file lib/core.sh
# @brief Bootstrap for install.sh and every module: strict mode, the runtime library,
#        settings, deploy options, logging.
# @description
#   First line of every module:
#     source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
#   A module then has:
#     - the runtime library, from the repo copy of configs/alias -- the one
#       implementation of platform detection (OS_* / PKG_MGR / SUDO / SYS_BASHRC and
#       the paths), log_*, menus and confirm, pkg_install / pkg_enable_epel, ...
#       Sourcing the repo copy means deploying works before anything is deployed.
#     - settings: config.sh, then config.local.sh (gitignored: secrets, overrides)
#     - deploy options, exported by install.sh so a module run alone behaves the same:
#         DF_DRY_RUN=1  show every change, make none
#         DF_YES=1      answer yes to every confirmation (sets UI_ASSUME_YES)
#         DF_ROOT=dir   write files under dir instead of / and run no commands:
#                       a sandbox for tests and for inspecting what would land where
#         DF_FORCE=1    run on a distro or release outside the supported set
#     - die / df_run / df_need_root / df_module_start (here) and the file primitives
#       of lib/deploy.sh: df_install, df_install_dir, df_block, df_render, df_check_*
#   The runtime log_* never exit; die does. That is the whole difference between the
#   two layers' logging -- one implementation, one exit policy each.

[[ -n "${_DF_CORE_LOADED:-}" ]] && return 0
_DF_CORE_LOADED=1

set -Eeuo pipefail
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_ROOT

DF_DRY_RUN="${DF_DRY_RUN:-0}"
DF_YES="${DF_YES:-0}"
DF_ROOT="${DF_ROOT:-}"
DF_ROOT="${DF_ROOT%/}"
DF_FORCE="${DF_FORCE:-0}"
export DF_DRY_RUN DF_YES DF_ROOT DF_FORCE

# The runtime library and the settings are written for interactive shells, where an
# unset variable is normal -- so they load with -u off, and strict mode resumes after.
set +u
# shellcheck source=../configs/alias/.bash_aliases
source "$DOTFILES_ROOT/configs/alias/.bash_aliases"
# shellcheck source=../config.sh
source "$DOTFILES_ROOT/config.sh"
if [[ -f "$DOTFILES_ROOT/config.local.sh" ]]; then
    # shellcheck disable=SC1091
    source "$DOTFILES_ROOT/config.local.sh"
fi
set -u
UI_ASSUME_YES="$DF_YES"

# @const DEPLOY_USER / DEPLOY_HOME
# @description The person being set up: whoever ran sudo, else the current user.
#              User-level modules (claude, node) write into DEPLOY_HOME as DEPLOY_USER.
DEPLOY_USER="${DEPLOY_USER:-${SUDO_USER:-$(id -un)}}"
DEPLOY_HOME="${DEPLOY_HOME:-$(getent passwd "$DEPLOY_USER" | cut -d: -f6)}"
DEPLOY_HOME="${DEPLOY_HOME:-/home/$DEPLOY_USER}"
export DEPLOY_USER DEPLOY_HOME

# @const DOTFILES_LOG_FILE
# @description One log per install run, shared by every module it starts (exported):
#              the runtime log_* append to it while the terminal stays colored.
#              Root runs log under DOTFILES_LOG_DIR/install; others (dry runs, tests)
#              under ~/.local/state/dotfiles/install.
if [[ -z "${DOTFILES_LOG_FILE:-}" ]]; then
    if (( EUID == 0 )) && [[ -z "$DF_ROOT" ]]; then
        _df_log_dir="$DOTFILES_LOG_DIR/install"
    else
        _df_log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/install"
    fi
    mkdir -p "$_df_log_dir"
    DOTFILES_LOG_FILE="$_df_log_dir/$(date +%Y%m%d-%H%M%S)-$$.log"
    unset _df_log_dir
fi
export DOTFILES_LOG_FILE

# @name die
# @description Log an error and exit 1. Deploy-only: the runtime library never exits.
# @example [[ -n "$DB_PASSWORD" ]] || die "Set DB_PASSWORD in config.local.sh"
die() {
    log_err "$*"
    exit 1
}

# A command failing outside a condition ends the module (set -e); say where.
trap 'log_err "Failed (exit $?) at ${BASH_SOURCE[0]##*/}:${LINENO}: ${BASH_COMMAND}"' ERR

# @name df_run
# @description Run a command that changes the system -- or, in a dry run or a DF_ROOT
#              sandbox, only print it. Every side effect that is not a file written by
#              lib/deploy.sh goes through here, which is what makes -n trustworthy.
# @example df_run systemctl enable --now cron
df_run() {
    if df_is_dry; then
        log_info "[dry-run] $*"
        return 0
    fi
    log_step "+ $*"
    "$@"
}

# @name df_is_dry
# @description Succeed when this run changes nothing on the real system: a dry run, or
#              a DF_ROOT sandbox (files go to the sandbox, commands are not run).
df_is_dry() { (( DF_DRY_RUN )) || [[ -n "$DF_ROOT" ]]; }

# @const DF_N
# @description ("-n") in a dry run or sandbox, else (): pass it to runtime helpers that
#              have their own dry-run flag, so they print what they would do with the
#              names resolved -- pkg_install "${DF_N[@]}" git jq
DF_N=()
if df_is_dry; then DF_N=(-n); fi

# @name df_as_user
# @description Run a bash snippet as DEPLOY_USER with their HOME: directly when we are
#              that user, else through runuser (util-linux, present on every target --
#              unlike sudo, which minimal images may lack). Only printed when dry.
# @example df_as_user 'nvm install --lts'
df_as_user() {
    if df_is_dry; then
        log_info "[dry-run] as ${DEPLOY_USER}: $1"
        return 0
    fi
    if [[ "$(id -un)" == "$DEPLOY_USER" ]]; then
        bash -c "$1"
    else
        runuser -u "$DEPLOY_USER" -- env HOME="$DEPLOY_HOME" bash -c "$1"
    fi
}

# @name df_need_root
# @description Die unless root -- except in a dry run or a sandbox, which change
#              nothing outside DF_ROOT and so need no privileges.
df_need_root() {
    (( EUID == 0 || DF_DRY_RUN )) || [[ -n "$DF_ROOT" ]] && return 0
    die "Module '${DF_MODULE:-?}' needs root -- run: sudo bash ${DOTFILES_ROOT}/install.sh ${DF_MODULE:-}"
}

# @name df_need_os
# @description Die on a distro or release outside the supported set, unless DF_FORCE=1.
df_need_os() {
    os_supported && return 0
    (( DF_FORCE )) && { log_warn "Unsupported ${OS_ID} ${OS_VERSION} -- continuing (DF_FORCE=1)"; return 0; }
    die "Unsupported: ${OS_ID} ${OS_VERSION}. Supported: Ubuntu 20.04+, Debian 11+, RHEL/Rocky/Alma 9+ (DF_FORCE=1 to try anyway)"
}

# @name df_module_start
# @description Standard module preamble: name the module, check the OS, announce the
#              mode. Root is checked separately (df_need_root): not every module needs it.
df_module_start() {
    DF_MODULE="${DF_MODULE:-$(basename "$(dirname "$(realpath "$0")")")}"
    log_banner "Module: ${DF_MODULE}"
    df_need_os
    (( DF_DRY_RUN )) && log_info "Dry run -- nothing will change"
    [[ -n "$DF_ROOT" ]] && log_info "Sandbox -- files go under ${DF_ROOT}, commands are not run"
    return 0
}

# shellcheck source=deploy.sh
source "$DOTFILES_ROOT/lib/deploy.sh"
