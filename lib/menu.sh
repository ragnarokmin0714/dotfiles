#!/usr/bin/env bash
# =============================================================================
# lib/menu.sh — Interactive Main Menu
# =============================================================================
# Renders an interactive selection menu using the bash `select` builtin.
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
  _run_module "network"
  _run_module "db"
  _run_module "project"
  log_success "All modules completed. Review logs in: $LOG_DIR"
}

# show_menu — Display the interactive menu and handle user selection
show_menu() {
  _print_banner

  local options=(
    "System Setup      (sudo, bashrc, apt packages)"
    "Network Setup     (static IP, DNS, firewall)"
    "Database Setup    (PostgreSQL, MySQL, Redis)"
    "Project Env Setup (Node.js, pnpm, Docker)"
    "ISO Build         (build custom Linux ISO)"
    "Shell Aliases     (deploy ~/.alias/ prompt + git + utils)"
    "Run ALL Modules   (full environment deployment)"
    "Quit"
  )

  echo -e "${COLOR_BOLD}Select a module to run:${COLOR_RESET}"
  PS3=$'\nEnter your choice [1-8]: '   # Custom prompt for select

  select opt in "${options[@]}"; do
    case "$REPLY" in
      1) _run_module "system"         ;;
      2) _run_module "network"        ;;
      3) _run_module "db"             ;;
      4) _run_module "project"        ;;
      5) _run_module "iso"            ;;
      6) _run_module "system/aliases" ;;
      7) _run_all                     ;;
      8)
        log_info "Exiting dotfiles setup."
        exit 0
        ;;
      *)
        log_warn "Invalid choice '$REPLY'. Please enter a number between 1 and 8."
        ;;
    esac

    # Re-display the menu after each completed action
    echo ""
    echo -e "${COLOR_BOLD}Select a module to run:${COLOR_RESET}"
  done
}
