#!/usr/bin/env bash
# =============================================================================
# lib/log.sh — Unified Logging Utility
# =============================================================================
# Provides four log-level functions used across all module scripts.
# Logs are written to both stdout (with color) and a timestamped file
# under the logs/ directory.
#
# USAGE:
#   source "$DOTFILES_ROOT/lib/log.sh"
#
#   log_info  "Starting network setup..."
#   log_warn  "Interface eth0 not found, using lo"
#   log_error "Failed to install package"   # exits with code 1
#   log_success "Network setup complete"
#
# LOG FILE:
#   logs/YYYYMMDD_HHMMSS_<script_name>.log
# =============================================================================

# Ensure the logs directory exists before writing
_ensure_log_dir() {
  local log_dir="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/logs"
  mkdir -p "$log_dir"
  echo "$log_dir"
}

# Resolve log file path once per script invocation
_LOG_DIR="$(_ensure_log_dir)"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[1]:-install}" .sh)"
LOG_FILE="$_LOG_DIR/$(date +%Y%m%d_%H%M%S)_${_SCRIPT_NAME}.log"

# Internal: write a raw line to the log file (no color codes in file)
_log_raw() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# log_info — General informational message (cyan)
log_info() {
  local msg="$*"
  echo -e "${COLOR_CYAN:-\033[0;36m}[INFO]${COLOR_RESET:-\033[0m}  $msg"
  _log_raw "INFO " "$msg"
}

# log_warn — Non-fatal warning (yellow). Execution continues.
log_warn() {
  local msg="$*"
  echo -e "${COLOR_YELLOW:-\033[1;33m}[WARN]${COLOR_RESET:-\033[0m}  $msg" >&2
  _log_raw "WARN " "$msg"
}

# log_error — Fatal error (red). Prints message and exits with code 1.
log_error() {
  local msg="$*"
  echo -e "${COLOR_RED:-\033[0;31m}[ERROR]${COLOR_RESET:-\033[0m} $msg" >&2
  _log_raw "ERROR" "$msg"
  exit 1
}

# log_success — Operation completed successfully (green)
log_success() {
  local msg="$*"
  echo -e "${COLOR_GREEN:-\033[0;32m}[OK]${COLOR_RESET:-\033[0m}    $msg"
  _log_raw "OK   " "$msg"
}

# log_section — Print a visual section header (bold)
log_section() {
  local title="$*"
  local line="$(printf '%0.s─' {1..60})"
  echo -e "\n${COLOR_BOLD:-\033[1m}${line}${COLOR_RESET:-\033[0m}"
  echo -e "${COLOR_BOLD:-\033[1m}  $title${COLOR_RESET:-\033[0m}"
  echo -e "${COLOR_BOLD:-\033[1m}${line}${COLOR_RESET:-\033[0m}\n"
  _log_raw "SECT " "=== $title ==="
}
