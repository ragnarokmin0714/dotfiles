#!/usr/bin/env bash
# =============================================================================
# install.sh — Dotfiles Main Entry Point
# =============================================================================
# The single command to bootstrap a complete Linux environment.
#
# USAGE:
#   Interactive menu (default):
#     sudo bash install.sh
#
#   Run a specific module non-interactively:
#     sudo bash install.sh --module network
#     sudo bash install.sh --module db
#     sudo bash install.sh --module project
#     sudo bash install.sh --module system
#     sudo bash install.sh --module iso
#
#   Run all modules sequentially:
#     sudo bash install.sh --all
#
# REQUIRES: sudo / root privileges for most modules
# =============================================================================
set -euo pipefail

# Resolve the dotfiles root directory (works regardless of where you call it from)
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load global constants and utilities
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"
source "$DOTFILES_ROOT/lib/menu.sh"

# --- Parse command-line arguments ---
# Defaults to interactive menu if no arguments provided
MODE="menu"
MODULE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      MODE="all"
      shift
      ;;
    --module)
      MODE="module"
      MODULE="${2:-}"
      if [[ -z "$MODULE" ]]; then
        log_error "--module requires a name (e.g. --module network)"
      fi
      shift 2
      ;;
    --help | -h)
      echo "Usage: sudo bash install.sh [--all | --module <name> | --help]"
      echo ""
      echo "Available modules: system  system/aliases  system/claude  network  db  project  iso"
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1. Run with --help for usage."
      ;;
  esac
done

# --- Privilege check ---
# Most modules require root to install packages and modify system files.
if [[ "$EUID" -ne 0 ]]; then
  log_warn "Not running as root. Some modules may fail. Re-run with: sudo bash $0"
fi

log_info "Dotfiles root: $DOTFILES_ROOT"
log_info "Log file:      $LOG_FILE"
log_info "Deploy user:   $DEPLOY_USER"

# --- Dispatch ---
case "$MODE" in
  all)
    _run_all
    ;;
  module)
    _run_module "$MODULE"
    ;;
  menu)
    show_menu
    ;;
esac
