#!/usr/bin/env bash
# @file .bash_functions
# @brief General system utility functions and aliases.
# @description
#   Provides helper functions for: IP address lookup, file search,
#   disk usage reporting, disk cleanup, and project runner shortcuts.
#   All functions depend on the STYLE associative array from .bash_env.

# =============================================================================
# --- System Utilities ---
# =============================================================================

# List globally installed npm packages at depth 0 in JSON format
alias npmlsg='npm list -g --depth=0 --json'

# Show network connections and listening ports
alias netstats='netstat -tulpn'
alias sss='ss -tulpn'

# --- ls Variants ---
# long format, include hidden files, human-readable size
alias lh='ls -lah'
# long format, hidden, sort by access time
alias lhu='lh -u'
# long format, hidden, sort by change time (ctime)
alias lhc='lh -c'
# long format, hidden, sort by size largest first
alias lhs='lh -S'
# long format, hidden, sort by extension
alias lhx='lh -X'
# long format, hidden, sort by modified time oldest first
alias lhtr='lh -tr'
# long format, hidden, sort by modified time newest first
alias lht='lh -t'

# --- Service Management ---
# List all running services
alias svc-running='systemctl list-units --type=service --state=running'
# List all failed services
alias svc-failed='systemctl list-units --type=service --state=failed'
# List all services (including inactive)
alias svc-all='systemctl list-units --type=service --all'
# Count total services
alias svc-count='systemctl list-units --type=service --all | grep -c .service'
# Show service status (usage: svc-status nginx)
alias svc-status='systemctl status'

# --- Datetime ---
# current datetime in YYYY-MM-DD HH:MM:SS format
alias now='date +"%Y-%m-%d %H:%M:%S"'
# current date in YYYY-MM-DD format
alias today='date +"%Y-%m-%d"'
# current time in HH:MM:SS format
alias time-now='date +"%H:%M:%S"'

# --- NTP / Time Sync ---
# Ubuntu/Debian uses systemd-timesyncd; Rocky/RHEL uses chronyd.
# All three functions below auto-detect the active NTP daemon.

# @name ntp_sync
# @description Step the clock immediately and sync hardware clock.
#              Rocky: chronyc makestep. Ubuntu: timedatectl only.
# @example ntp_sync
# @example ntp-sync
ntp_sync() {
    if command -v chronyc &>/dev/null; then
        sudo chronyc makestep
        sudo hwclock --systohc
        chronyc tracking
    else
        sudo timedatectl set-ntp true
    fi
    timedatectl
}
alias ntp-sync='ntp_sync'

# @name ntp_status
# @description Show current NTP sync status.
#              Rocky: chronyc tracking. Ubuntu: timedatectl timesync-status.
# @example ntp_status
# @example ntp-status
ntp_status() {
    timedatectl status
    if command -v chronyc &>/dev/null; then
        echo "--- chronyc tracking ---"
        chronyc tracking
    elif systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
        echo "--- timesync-status ---"
        timedatectl timesync-status
    fi
}
alias ntp-status='ntp_status'

# @name ntp_fix
# @description Enable NTP and restart the appropriate time sync service.
#              Rocky: chronyd. Ubuntu: systemd-timesyncd.
# @example ntp_fix
# @example ntp-fix
ntp_fix() {
    sudo timedatectl set-ntp true
    if command -v chronyd &>/dev/null || systemctl list-unit-files 2>/dev/null | grep -q 'chronyd.service'; then
        echo "Restarting chronyd..."
        sudo systemctl restart chronyd
    elif systemctl list-unit-files 2>/dev/null | grep -q 'systemd-timesyncd.service'; then
        echo "Restarting systemd-timesyncd..."
        sudo systemctl restart systemd-timesyncd
    else
        echo "[WARN] No known NTP service found (chronyd / systemd-timesyncd)"
    fi
    sleep 3
    timedatectl status
}
alias ntp-fix='ntp_fix'

# --- Timezone ---

# @name tz
# @description Interactive timezone manager.
#              No args  → show current timezone + menu of common zones.
#              With arg → set timezone directly (exact) or list fuzzy matches.
# @param $1 string  Optional: exact timezone or partial keyword (e.g. "Asia/Taipei", "Asia")
# @example tz
# @example tz Asia/Taipei
# @example tz Asia
tz() {
    local COMMON_TZ=(
        "Asia/Taipei"
        "Asia/Tokyo"
        "Asia/Shanghai"
        "Asia/Singapore"
        "Asia/Seoul"
        "UTC"
        "Europe/London"
        "Europe/Paris"
        "America/New_York"
        "America/Los_Angeles"
    )

    _tz_apply() {
        sudo timedatectl set-timezone "$1"
        echo "[OK] Timezone set to: $1"
        timedatectl | grep -E "Local time|Time zone"
    }

    # ── With argument: exact or fuzzy ──────────────────────────────────────
    if [[ -n "$1" ]]; then
        if timedatectl list-timezones 2>/dev/null | grep -qx "$1"; then
            _tz_apply "$1"
            return 0
        fi

        local matches
        matches=$(timedatectl list-timezones 2>/dev/null | grep -i "$1")

        if [[ -z "$matches" ]]; then
            echo "[X] No timezone found for: $1"
            return 1
        fi

        echo "Matching timezones:"
        local -a match_arr
        mapfile -t match_arr <<< "$matches"
        local i
        for i in "${!match_arr[@]}"; do
            printf "  %2d) %s\n" "$((i+1))" "${match_arr[$i]}"
        done
        echo ""
        printf "Enter number (or press Enter to cancel): "
        read -r sel
        [[ -z "$sel" ]] && echo "Cancelled." && return 0
        if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#match_arr[@]} )); then
            _tz_apply "${match_arr[$((sel-1))]}"
        else
            echo "[X] Invalid selection."
            return 1
        fi
        return 0
    fi

    # ── No argument: show current + common zones menu ──────────────────────
    echo "Current timezone:"
    timedatectl | grep -E "Local time|Time zone"
    echo ""
    echo "Common timezones:"
    local i
    for i in "${!COMMON_TZ[@]}"; do
        printf "  %2d) %s\n" "$((i+1))" "${COMMON_TZ[$i]}"
    done
    printf "  %2d) Enter manually\n" "$((${#COMMON_TZ[@]}+1))"
    echo ""
    printf "Enter number (or press Enter to cancel): "
    read -r sel

    [[ -z "$sel" ]] && echo "Cancelled." && return 0

    local manual_opt=$(( ${#COMMON_TZ[@]} + 1 ))
    if [[ "$sel" == "$manual_opt" ]]; then
        printf "Timezone (e.g. Asia/Taipei): "
        read -r manual
        [[ -z "$manual" ]] && echo "Cancelled." && return 0
        if timedatectl list-timezones 2>/dev/null | grep -qx "$manual"; then
            _tz_apply "$manual"
        else
            echo "[X] Invalid timezone: $manual"
            return 1
        fi
    elif [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#COMMON_TZ[@]} )); then
        _tz_apply "${COMMON_TZ[$((sel-1))]}"
    else
        echo "[X] Invalid selection."
        return 1
    fi
}

# @name reload_shell
# @description Reload the current shell by sourcing the system-wide bashrc.
#              Auto-detects /etc/bashrc (Rocky/RHEL) or /etc/bash.bashrc (Ubuntu/Debian).
# @example reload_shell
# @example rl
reload_shell() {
    if [[ -f /etc/bashrc ]]; then
        # shellcheck disable=SC1091
        source /etc/bashrc
        echo "[OK] Reloaded /etc/bashrc"
    elif [[ -f /etc/bash.bashrc ]]; then
        # shellcheck disable=SC1091
        source /etc/bash.bashrc
        echo "[OK] Reloaded /etc/bash.bashrc"
    else
        echo "[WARN] No system bashrc found — try: source ~/.bashrc"
    fi
}
alias rl='reload_shell'

# @name get_ip
# @description Get primary IPv4 address for prompt display.
#              Uses 'hostname -I' and awk to extract the first IP.
#              Silent if no IP is found.
# @example get_ip
get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}
alias get-ip='get_ip'

# @name find_path
# @description Find files or directories by name under a given path.
#              Automatically splits a full path argument into pattern + directory.
#              Mimics the `fd` tool using standard `find`.
# @param $1 string  Pattern or full path (e.g. "*.log" or "~/.config/settings.json")
# @param $2 string  Optional: path to search in (default: current directory)
# @param $3 string  Optional: file type — f (file), d (directory), l (symlink)
# @param $4 int     Optional: max search depth
# @example find_path "myfile.txt"
# @example find_path "*.log" /var/log
# @example find_path "*.conf" /etc f
# @example find_path "logs" . d
# @example find_path "*.txt" . f 2
# @example find_path ~/.config/settings.json
find_path() {
    local pattern="$1"
    local path="${2:-.}"
    local type="$3"
    local depth="$4"

    # Warn if pattern looks like it was glob-expanded by the shell
    if [[ $# -gt 1 && "$2" != /* && "$2" != "." && "$2" != ".." && ! "$2" =~ ^[fdle]$ ]]; then
        echo -e "${STYLE[fg_yellow]}[!] Tip: use quotes to prevent glob expansion: fp \"${pattern}-*\"${STYLE[reset]}"
    fi

    # Auto-split full path into pattern + search directory
    if [[ "$pattern" == */* ]]; then
        path=$(dirname "$pattern")
        pattern=$(basename "$pattern")
    fi

    local args=()
    [[ -n "$type" ]]  && args+=(-type "$type")
    [[ -n "$depth" ]] && args+=(-maxdepth "$depth")

    local results
    results=$(find "$path" -name "$pattern" "${args[@]}")

    if [[ -n "$results" ]]; then
        echo -e "${STYLE[bg_green]}[V]${STYLE[reset]} ${STYLE[fg_green]}Found the following matches:${STYLE[reset]}"
        echo -e "${STYLE[fg_bright_green]}${results}${STYLE[reset]}"
    else
        echo -e "${STYLE[bg_red]}[X]${STYLE[reset]} ${STYLE[fg_red]}No matches found for:${STYLE[reset]} ${STYLE[fg_bright_red]}${pattern}${STYLE[reset]}"
    fi
}
alias fp='find_path'

# =============================================================================
# --- Disk Utilities ---
# =============================================================================

# @name disk_usage_top
# @description Display disk usage for a given path (default: $HOME),
#              showing the top N largest entries (default: 20).
# @param $1 string  Optional: path to check (default: $HOME)
# @param $2 int     Optional: number of entries to show (default: 20)
# @example disk_usage_top
# @example disk_usage_top /var
# @example disk_usage_top /var 10
disk_usage_top() {
    local target="${1:-$HOME}"
    local count="${2:-20}"
    du -h --max-depth=1 "$target" | sort -hr | head -n "$count"
}
alias disk-usage-top='disk_usage_top'
alias dut='disk_usage_top'

# @name clean_up_disk
# @description Perform comprehensive disk cleanup:
#              - Clean npm and pnpm caches
#              - Clean package manager cache (apt or dnf — auto-detected)
#              - Remove unused dependencies and old kernels
# @distro  Ubuntu / Debian  → apt
#          Rocky / RHEL / Fedora → dnf
# @example clean_up_disk
clean_up_disk() {
    # Guard: only run if tools are installed
    if command -v npm &>/dev/null; then
        echo "Cleaning npm cache..."
        npm cache clean --force
    else
        echo "[SKIP] npm not installed — skipping npm cache cleanup."
    fi

    if command -v pnpm &>/dev/null; then
        echo "Cleaning pnpm store..."
        pnpm store prune
    else
        echo "[SKIP] pnpm not installed — skipping pnpm store cleanup."
    fi

    # Detect package manager
    if command -v apt-get &>/dev/null; then
        echo "Detected apt (Ubuntu/Debian) — cleaning package cache..."
        sudo apt-get clean
        sudo apt-get autoclean
        sudo apt-get autoremove -y
        # Remove old kernel packages (keep current)
        local current_kernel
        current_kernel=$(uname -r)
        echo "Current kernel: $current_kernel — removing older kernels..."
        dpkg -l 'linux-image-*' 2>/dev/null \
            | awk '/^ii/{print $2}' \
            | grep -v "$current_kernel" \
            | grep -v 'linux-image-generic' \
            | xargs -r sudo apt-get remove -y --purge
    elif command -v dnf &>/dev/null; then
        echo "Detected dnf (Rocky/RHEL/Fedora) — cleaning package cache..."
        sudo dnf clean all
        sudo dnf autoremove -y
        sudo dnf remove --oldinstallonly -y
    else
        echo "[WARN] No supported package manager found (apt/dnf). Skipping system cache cleanup."
    fi

    echo "Disk cleanup completed."
    df -h
}
alias clean-up-disk='clean_up_disk'
alias cud='clean_up_disk'

# @name sys_update
# @description Update and upgrade system packages.
# @distro  Ubuntu / Debian  → apt
#          Rocky / RHEL / Fedora → dnf
# @example sys_update
sys_update() {
    if command -v apt &>/dev/null; then
        echo "Updating via apt..."
        sudo apt update -y && sudo apt upgrade -y
    elif command -v dnf &>/dev/null; then
        echo "Updating via dnf..."
        sudo dnf update -y
    else
        echo "No supported package manager found (apt/dnf)"
        return 1
    fi
}
alias sys-update='sys_update'
alias sup='sys_update'

# @name sys_maintain
# @description Update system packages and clean up disk.
# @depends sys_update, clean_up_disk
# @example sys_maintain
sys_maintain() {
    sys_update && clean_up_disk
}
alias sys-maint='sys_maintain'
# =============================================================================

# Quickly change to the uploads directory
alias cduploads='cd /srv/www/bidsystem/uploads/'

# @name run_project
# @description Run a pnpm script inside a specific project directory.
#              Avoids repetitive cd + pnpm commands, validates input,
#              and improves developer experience.
# @param $1 string  pnpm script name defined in package.json (default: "dev")
# @param $2 string  Project directory path (default: /etc/moneytek/construction_pmis)
# @example run_project
# @example run_project dev /path/to/myproject
# @example run_project start:prod /path/to/myproject
run_project() {
    local script="${1:-dev}"
    local project="${2:-/etc/moneytek/construction_pmis}"

    cd "$project" || { echo "Project not found: $project"; return 1; }

    echo "Running pnpm $script in $project"
    pnpm "$script"
}
alias run-prj='run_project'

# Shortcuts for the default project
alias run-dev='run_project dev'
alias run-prj-dev='run_project dev'
alias run-prod='run_project start:prod'
alias run-prj-prod='run_project start:prod'

# Stop the dev server running on port 3001
alias stop-dev='port=$(sss | grep 3001 | grep -oP "(?<=pid=)[0-9]+") && echo "Stopping Dev server on port 3001 (pid=${port})" && kill "$port"'

# =============================================================================
# --- Package Utilities ---
# =============================================================================

# @name pkg_installed
# @description Check if a package is installed (supports apt and dnf).
# @param $1 string Package name to check
# @example pkg_installed nginx
# @example pkg_installed git
pkg_installed() {
    local pkg="$1"
    local FG_GREEN="${STYLE[fg_green]}"
    local FG_RED="${STYLE[fg_red]}"
    local BG_GREEN="${STYLE[bg_green]}"
    local BG_RED="${STYLE[bg_red]}"
    local RESET="${STYLE[reset]}"

    if [[ -z "$pkg" ]]; then
        echo -e "${BG_RED}[X]${RESET} ${FG_RED}Usage: pkg_installed <package>${RESET}"
        return 1
    fi

    # Detect package manager and check
    if command -v dnf &>/dev/null; then
        dnf list installed "$pkg" &>/dev/null
    elif command -v apt &>/dev/null; then
        dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"
    else
        echo -e "${BG_RED}[X]${RESET} ${FG_RED}No supported package manager found (apt/dnf)${RESET}"
        return 2
    fi

    if [[ $? -eq 0 ]]; then
        echo -e "${BG_GREEN}[V]${RESET} ${FG_GREEN}${pkg} is installed${RESET}"
        return 0
    else
        echo -e "${BG_RED}[X]${RESET} ${FG_RED}${pkg} is not installed${RESET}"
        return 1
    fi
}
alias pi='pkg_installed'

# @name pkg_ensure
# @description Check if a package is installed; prompt to install if not.
#              Supports apt (Ubuntu/Debian) and dnf (Rocky/RHEL).
# @param $1 string Package name to check and optionally install
# @example pkg_ensure nginx
# @example pkg_ensure git
pkg_ensure() {
    local pkg="$1"
    local FG_GREEN="${STYLE[fg_green]}"
    local FG_RED="${STYLE[fg_red]}"
    local FG_YELLOW="${STYLE[fg_yellow]}"
    local BG_GREEN="${STYLE[bg_green]}"
    local BG_RED="${STYLE[bg_red]}"
    local BG_YELLOW="${STYLE[bg_yellow]}"
    local RESET="${STYLE[reset]}"

    if [[ -z "$pkg" ]]; then
        echo -e "${BG_RED}[X]${RESET} ${FG_RED}Usage: pkg_ensure <package>${RESET}"
        return 1
    fi

    # Detect package manager
    local mgr=""
    if command -v dnf &>/dev/null; then
        mgr="dnf"
    elif command -v apt &>/dev/null; then
        mgr="apt"
    else
        echo -e "${BG_RED}[X]${RESET} ${FG_RED}No supported package manager found (apt/dnf)${RESET}"
        return 2
    fi

    # Check if already installed
    local installed=false
    if [[ "$mgr" == "dnf" ]]; then
        dnf list installed "$pkg" &>/dev/null && installed=true
    else
        dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" && installed=true
    fi

    if [[ "$installed" == true ]]; then
        echo -e "${BG_GREEN}[V]${RESET} ${FG_GREEN}${pkg} is already installed${RESET}"
        return 0
    fi

    # Prompt to install
    echo -e "${BG_RED}[X]${RESET} ${FG_RED}${pkg} is not installed${RESET}"
    echo -e "${BG_YELLOW}[?]${RESET} ${FG_YELLOW}Install ${pkg} now? (y/N): ${RESET}\c"
    read -r answer

    if [[ "${answer,,}" == "y" ]]; then
        echo -e "${FG_YELLOW}Installing ${pkg} via ${mgr}...${RESET}"
        if [[ "$mgr" == "dnf" ]]; then
            sudo dnf install -y "$pkg"
        else
            sudo apt install -y "$pkg"
        fi

        if [[ $? -eq 0 ]]; then
            echo -e "${BG_GREEN}[V]${RESET} ${FG_GREEN}${pkg} installed successfully${RESET}"
        else
            echo -e "${BG_RED}[X]${RESET} ${FG_RED}Failed to install ${pkg}${RESET}"
            return 1
        fi
    else
        echo -e "${FG_YELLOW}Skipped installation of ${pkg}${RESET}"
        return 1
    fi
}
alias pe='pkg_ensure'

# @name pkg_remove
# @description Check if a package is installed; prompt to remove if it is.
#              Supports apt (Ubuntu/Debian) and dnf (Rocky/RHEL).
# @param $1 string Package name to check and optionally remove
# @example pkg_remove nginx
# @example pkg_remove git
pkg_remove() {
    local pkg="$1"
    local FG_GREEN="${STYLE[fg_green]}"
    local FG_RED="${STYLE[fg_red]}"
    local FG_YELLOW="${STYLE[fg_yellow]}"
    local BG_GREEN="${STYLE[bg_green]}"
    local BG_RED="${STYLE[bg_red]}"
    local BG_YELLOW="${STYLE[bg_yellow]}"
    local RESET="${STYLE[reset]}"

    if [[ -z "$pkg" ]]; then
        echo -e "${BG_RED}[X]${RESET} ${FG_RED}Usage: pkg_remove <package>${RESET}"
        return 1
    fi

    # Detect package manager
    local mgr=""
    if command -v dnf &>/dev/null; then
        mgr="dnf"
    elif command -v apt &>/dev/null; then
        mgr="apt"
    else
        echo -e "${BG_RED}[X]${RESET} ${FG_RED}No supported package manager found (apt/dnf)${RESET}"
        return 2
    fi

    # Check if installed
    local installed=false
    if [[ "$mgr" == "dnf" ]]; then
        dnf list installed "$pkg" &>/dev/null && installed=true
    else
        dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" && installed=true
    fi

    if [[ "$installed" != true ]]; then
        echo -e "${BG_GREEN}[V]${RESET} ${FG_GREEN}${pkg} is not installed — nothing to remove${RESET}"
        return 0
    fi

    # Prompt to remove
    echo -e "${BG_YELLOW}[?]${RESET} ${FG_YELLOW}Remove ${pkg} now? (y/N): ${RESET}\c"
    read -r answer

    if [[ "${answer,,}" == "y" ]]; then
        echo -e "${FG_YELLOW}Removing ${pkg} via ${mgr}...${RESET}"
        if [[ "$mgr" == "dnf" ]]; then
            sudo dnf remove -y "$pkg"
        else
            sudo apt remove -y "$pkg"
        fi

        if [[ $? -eq 0 ]]; then
            echo -e "${BG_GREEN}[V]${RESET} ${FG_GREEN}${pkg} removed successfully${RESET}"
        else
            echo -e "${BG_RED}[X]${RESET} ${FG_RED}Failed to remove ${pkg}${RESET}"
            return 1
        fi
    else
        echo -e "${FG_YELLOW}Skipped removal of ${pkg}${RESET}"
        return 1
    fi
}
alias prm='pkg_remove'
