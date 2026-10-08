#!/usr/bin/env bash
# =============================================================================
# lib/log.sh — Unified Logging Utility
# =============================================================================
# Provides the log-level functions used across all module scripts.
# Every message goes to the timestamped file under logs/ (always plain);
# terminal output follows the same visual idiom as configs/alias/.bash_env
# (symbol prefix [V]/[X]/[~]/[i], colored message, NO_COLOR / non-TTY plain
# fallback). Independent implementation on purpose — see CLAUDE.md rule P2:
# this layer must stay self-contained and log_error must exit.
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

# Internal: succeed (0) when output on the given fd should be colored —
# the fd is a terminal and NO_COLOR is unset (same switch as .bash_env).
_log_color() { [[ -t "$1" && -z "${NO_COLOR+set}" ]]; }

# Internal: emit one leveled line to the terminal AND the log file.
# Terminal: "<colored symbol> <colored message>"; non-TTY / NO_COLOR:
# "<ts> [LABEL] message" (still readable and greppable when piped).
# Args: $1 fd (1|2), $2 symbol bg color, $3 symbol, $4 msg color, $5 label, $6.. message
_log_emit() {
  local fd="$1" sym_color="$2" symbol="$3" msg_color="$4" label="$5"
  shift 5
  local msg="$*"
  if _log_color "$fd"; then
    echo -e "${sym_color}${symbol}${COLOR_RESET:-\033[0m} ${msg_color}${msg}${COLOR_RESET:-\033[0m}"
  else
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$label" "$msg"
  fi
  _log_raw "$label" "$msg"
}

# log_info — General informational message (cyan [i])
log_info() {
  _log_emit 1 "${COLOR_CYAN:-\033[0;36m}" "[i]" "${COLOR_CYAN:-\033[0;36m}" "INFO " "$@"
}

# log_warn — Non-fatal warning (yellow [~]). Execution continues.
log_warn() {
  _log_emit 2 "${COLOR_BG_YELLOW:-\033[43m}" "[~]" "${COLOR_YELLOW:-\033[1;33m}" "WARN " "$@" >&2
}

# log_error — Fatal error (red [X]). Prints message and exits with code 1.
log_error() {
  _log_emit 2 "${COLOR_BG_RED:-\033[41m}" "[X]" "${COLOR_RED:-\033[0;31m}" "ERROR" "$@" >&2
  exit 1
}

# log_success — Operation completed successfully (green [V])
log_success() {
  _log_emit 1 "${COLOR_BG_GREEN:-\033[42m}" "[V]" "${COLOR_GREEN:-\033[0;32m}" "OK   " "$@"
}

# log_section — Boxed section header (bold cyan ╔═╗ box, like .bash_env's
# log_banner). Borders auto-size to the title length; plain box when piped.
log_section() {
  local title="$*"
  local bar
  bar=$(printf '═%.0s' $(seq 1 $(( ${#title} + 2 ))))
  if _log_color 1; then
    echo -e "\n${COLOR_BOLD:-\033[1m}${COLOR_CYAN:-\033[0;36m}╔${bar}╗${COLOR_RESET:-\033[0m}"
    echo -e "${COLOR_BOLD:-\033[1m}${COLOR_CYAN:-\033[0;36m}║ ${title} ║${COLOR_RESET:-\033[0m}"
    echo -e "${COLOR_BOLD:-\033[1m}${COLOR_CYAN:-\033[0;36m}╚${bar}╝${COLOR_RESET:-\033[0m}\n"
  else
    printf '\n╔%s╗\n║ %s ║\n╚%s╝\n\n' "$bar" "$title" "$bar"
  fi
  _log_raw "SECT " "=== $title ==="
}
