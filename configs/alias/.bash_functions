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
    echo "Cleaning npm cache..."
    npm cache clean --force

    echo "Cleaning pnpm store..."
    pnpm store prune

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

# =============================================================================
# --- Project Commands ---
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
