#!/usr/bin/env bash
# @file install.sh
# @brief Entry point: pick modules (or name them) and run them in order.
# @description
#   Modules are discovered, not registered: every modules/<name>/main.sh is one, and
#   its header says what it is --
#     # @desc   one line shown in the menu and --list
#     # @order  number; modules always run in this order, whatever order they were named
#     # @manual present = left out of --all (risky, or rarely wanted everywhere)
#   Adding a module is adding a directory; nothing else needs editing.
set -Eeuo pipefail

usage() {
    cat <<'EOF'
usage: install.sh [options] [module...]

  With no module: pick from a menu (needs a terminal).

  -l, --list       list modules and exit
  -a, --all        every module not marked manual
  -n, --dry-run    show every change, make none (no root needed)
  -y, --yes        answer yes to every question
      --root DIR   sandbox: write files under DIR, run no commands (no root needed)
  -h, --help       this help

  e.g.  sudo bash install.sh shell maint
        bash install.sh -n --all
        OS_FAMILY=rhel OS_ID=rocky OS_VERSION=9.4 bash install.sh -n --all
EOF
}

# --- Options (parsed before core.sh, which reads them from the environment) ----
mode=run
all=0
declare -a requested=()
while (( $# )); do
    case "$1" in
        -l | --list)    mode=list ;;
        -a | --all)     all=1 ;;
        -n | --dry-run) export DF_DRY_RUN=1 ;;
        -y | --yes)     export DF_YES=1 ;;
        --root)         [[ -n "${2:-}" ]] || { usage >&2; exit 2; }
                        mkdir -p "$2"; DF_ROOT="$(cd "$2" && pwd)"; export DF_ROOT; shift ;;
        -h | --help)    usage; exit 0 ;;
        -*)             echo "install.sh: unknown option $1" >&2; usage >&2; exit 2 ;;
        *)              requested+=("$1") ;;
    esac
    shift
done

# shellcheck source=lib/core.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/core.sh"

# --- Discover modules -------------------------------------------------------------
declare -A desc=() order=() manual=()
declare -a names=()
for main in "$DOTFILES_ROOT"/modules/*/main.sh; do
    name=$(basename "$(dirname "$main")")
    names+=("$name")
    desc[$name]=$(sed -n 's/^# @desc[[:space:]]*//p' "$main" | head -1)
    order[$name]=$(sed -n 's/^# @order[[:space:]]*//p' "$main" | head -1)
    if grep -q '^# @manual' "$main"; then manual[$name]=1; fi
done
mapfile -t names < <(for n in "${names[@]}"; do printf '%s %s\n' "${order[$n]:-99}" "$n"; done | sort -n | cut -d' ' -f2)

label() { printf '%-9s %s%s' "$1" "${desc[$1]}" "${manual[$1]:+  [manual]}"; }

if [[ "$mode" == list ]]; then
    for n in "${names[@]}"; do label "$n"; echo; done
    echo
    echo "[manual] = not part of --all"
    exit 0
fi

# --- Choose ------------------------------------------------------------------------
declare -a selected=()
if (( all )); then
    for n in "${names[@]}"; do [[ -n "${manual[$n]:-}" ]] || selected+=("$n"); done
fi
for r in "${requested[@]}"; do
    [[ -n "${desc[$r]+set}" ]] || die "Unknown module: ${r} (see: install.sh --list)"
    selected+=("$r")
done
if (( ${#selected[@]} == 0 )); then
    ui_tty || { usage >&2; exit 2; }
    declare -a labels=()
    for n in "${names[@]}"; do labels+=("$(label "$n")"); done
    log_banner "dotfiles -- ${OS_ID} ${OS_VERSION} (${OS_FAMILY}), user ${DEPLOY_USER}"
    picks=""
    multiselect picks "Run which modules?" "${labels[@]}" || { log_info "Cancelled"; exit 0; }
    for i in $picks; do selected+=("${names[$i]}"); done
    (( ${#selected[@]} )) || { log_info "Nothing selected"; exit 0; }
fi
# Run order is @order, however they were named; drop repeats
mapfile -t selected < <(for n in "${selected[@]}"; do printf '%s %s\n' "${order[$n]:-99}" "$n"; done | sort -n | awk '!seen[$0]++' | cut -d' ' -f2)

# --- Run ---------------------------------------------------------------------------
df_need_os
log_head "Plan: ${selected[*]}"
(( DF_DRY_RUN )) && log_info "Dry run -- nothing will change"
[[ -n "$DF_ROOT" ]] && log_info "Sandbox: ${DF_ROOT}"
log_info "Log: ${DOTFILES_LOG_FILE}"
if (( ! DF_DRY_RUN )) && [[ -z "$DF_ROOT" ]]; then
    confirm "Run ${#selected[@]} module(s) on $(hostname)?" || { log_info "Cancelled"; exit 0; }
fi

declare -a done_mods=()
for n in "${selected[@]}"; do
    if ! DF_MODULE="$n" bash "$DOTFILES_ROOT/modules/$n/main.sh"; then
        log_err "Module '${n}' failed -- stopped. Done: ${done_mods[*]:-none}. Log: ${DOTFILES_LOG_FILE}"
        exit 1
    fi
    done_mods+=("$n")
done
log_ok "Done: ${done_mods[*]}"
log_info "Log: ${DOTFILES_LOG_FILE}"
