#!/usr/bin/env bash
# =============================================================================
# lib/menu.sh — Interactive Main Menu
# =============================================================================
# Renders an interactive cursor-driven menu modeled on the multiselect engine
# in configs/alias/.bash_pkg (independent copy on purpose — see CLAUDE.md rule
# P2: deploy layer never sources the alias layer). Single-select variant:
# Up/Down or j/k to move, 1-9/0 to jump-run, ENTER to run, q to quit.
# This file is sourced by install.sh and exposes show_menu().
#
# USAGE:
#   source "$DOTFILES_ROOT/lib/menu.sh"
#   show_menu
#
# DEPENDENCIES:
#   - lib/env.sh   (for DOTFILES_ROOT, color codes)
#   - lib/log.sh   (for log_info, log_error)
# =============================================================================

# _print_banner — Display the dotfiles ASCII banner
_print_banner() {
  echo -e "${COLOR_CYAN}"
  cat << 'EOF'
  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
  ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
  ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
EOF
  echo -e "${COLOR_RESET}  Linux Environment Automation — v1.0.0"
  echo -e "  Running as: ${COLOR_BOLD}$(whoami)${COLOR_RESET} on ${COLOR_BOLD}$(hostname)${COLOR_RESET}"
  echo ""
}

# _menu_select — Cursor-driven single-select menu (multiselect-style UI).
# Up/Down or j/k to move, 1-9/0 to jump straight to an entry, ENTER to
# confirm, q to cancel. Writes the SELECTED INDEX (0-based, in menu order)
# into the caller's named variable.
# Args: $1 = out-var name, $2 = header function name (or ""), $3 = title,
#       $4.. = option labels
# Returns: 0 on confirm (index in the out-var); 1 on cancel (out-var emptied)
_menu_select() {
  local result_var="$1" header_fn="$2" title="$3"
  shift 3
  local -a labels=("$@")
  local cursor=0
  local i key rest idx

  while true; do
    clear
    [[ -n "$header_fn" ]] && "$header_fn"
    echo -e "${COLOR_BOLD}${title}${COLOR_RESET}"
    echo ""
    for i in "${!labels[@]}"; do
      if [[ "$i" -eq "$cursor" ]]; then
        # Cursor row: reverse-video whole line (same idiom as multiselect).
        echo -e "  ${COLOR_REVERSE}$(( i + 1 ))) ${labels[$i]}${COLOR_RESET}"
      else
        echo -e "  $(( i + 1 ))) ${labels[$i]}"
      fi
    done
    echo ""
    echo -e "  Up/Down·jk move · 1-9/0 jump · ENTER run · q quit"

    IFS= read -rsn1 key
    if [[ "$key" == $'\e' ]]; then
      read -rsn2 -t 1 rest   # -t guards against a lone ESC hanging the read
      case "$rest" in
        '[A') (( cursor > 0 )) && (( cursor-- )) ;;
        '[B') (( cursor < ${#labels[@]} - 1 )) && (( cursor++ )) ;;
      esac
      continue
    fi
    case "$key" in
      k | K) (( cursor > 0 )) && (( cursor-- )) ;;
      j | J) (( cursor < ${#labels[@]} - 1 )) && (( cursor++ )) ;;
      [1-9] | 0)
        # Digit jump-run: 1-9 → entries 1-9, 0 → entry 10.
        idx=$(( key == 0 ? 9 : key - 1 ))
        if (( idx < ${#labels[@]} )); then
          cursor="$idx"
          break
        fi
        ;;
      q | Q) clear; printf -v "$result_var" '%s' ""; return 1 ;;
      '') break ;;   # ENTER
    esac
  done
  clear

  printf -v "$result_var" '%s' "$cursor"
  return 0
}

# _run_module — Source and execute a module's setup.sh (or explicit .sh path) safely
# Args: $1 = module directory name (e.g. "network") OR path without .sh (e.g. "system/aliases")
_run_module() {
  local module="$1"
  local script

  # Support both "module/" (uses setup.sh) and explicit "module/file" paths
  if [[ -f "$DOTFILES_ROOT/${module}.sh" ]]; then
    script="$DOTFILES_ROOT/${module}.sh"
  else
    script="$DOTFILES_ROOT/$module/setup.sh"
  fi

  if [[ ! -f "$script" ]]; then
    log_error "Module script not found: $script"
  fi

  log_section "Running module: $module"
  bash "$script"
  log_success "Module '$module' completed."
}

# _run_all — Execute every module in the recommended order
_run_all() {
  log_section "Running ALL modules"
  _run_module "system"
  _run_module "system/aliases"
  _run_module "system/claude"
  _run_module "network"
  _run_module "db"
  _run_module "project"
  log_success "All modules completed. Review logs in: $LOG_DIR"
}

# show_menu — Display the interactive menu and handle user selection
show_menu() {
  if [[ ! -t 0 ]]; then
    log_error "Interactive menu needs a TTY. Use --module <name> or --all instead."
  fi

  # Menu order == dispatch order: MODULES[i] runs for menu entry i.
  # The two trailing entries (Run ALL / Quit) are handled specially below.
  local -a options=(
    "System Setup      (sudo, bashrc, apt packages)"
    "Network Setup     (static IP, DNS, firewall)"
    "HTTPS Setup       (nginx install/reinstall + OpenSSL self-signed cert)"
    "Database Setup    (PostgreSQL, MySQL, Redis)"
    "Project Env Setup (Node.js, pnpm, Docker)"
    "ISO Build         (build custom Linux ISO)"
    "Shell Aliases     (deploy alias modules: prompt + git + pkg + utils)"
    "Claude Code       (deploy ~/.claude/ agents + commands + skills + hooks)"
    "Run ALL Modules   (full environment deployment)"
    "Quit"
  )
  local -a modules=(
    system network network/https db project iso system/aliases system/claude
  )

  local choice
  while true; do
    if ! _menu_select choice _print_banner "Select a module to run:" "${options[@]}"; then
      log_info "Exiting dotfiles setup."
      exit 0
    fi

    if (( choice == ${#options[@]} - 1 )); then          # Quit
      log_info "Exiting dotfiles setup."
      exit 0
    elif (( choice == ${#options[@]} - 2 )); then        # Run ALL
      _run_all
    else
      _run_module "${modules[$choice]}"
    fi

    echo ""
    read -rp "Press ENTER to return to the menu..."
  done
}
