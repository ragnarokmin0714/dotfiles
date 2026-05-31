############################################################
# =========================
# --- System Utilities ---
# =========================

# List globally installed npm packages (depth 0) in JSON format
alias npmlsg='npm list -g --depth=0 --json'

# Show network connections and listening ports
alias netstats='netstat -tulpn'
alias sss='ss -tulpn'

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

# current datetime in YYYY-MM-DD HH:MM:SS format
alias now='date +"%Y-%m-%d %H:%M:%S"'
# current date in YYYY-MM-DD format
alias today='date +"%Y-%m-%d"'
# current time in HH:MM:SS format
alias time-now='date +"%H:%M:%S"'

# Enable NTP and restart time sync service
alias ntp-sync='sudo chronyc makestep && sudo hwclock --systohc && chronyc tracking && timedatectl'
# Show current time sync status
alias ntp-status='timedatectl status && timedatectl timesync-status'
# Fix NTP sync and verify result
alias ntp-fix='sudo timedatectl set-ntp true && sudo systemctl restart systemd-timesyncd && sleep 3 && timedatectl status'

## @name get_ip
## @description Get primary IPv4 address for prompt display.
##              Uses 'hostname -I' and awk to extract first IP.
##              Silent if no IP is found.
## @example get_ip
get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}
alias get-ip='get_ip'

# @name find_path
# @description Find files or directories by name under a given path (mimics `fd` tool).
#              Automatically splits a full path into pattern and search directory.
# @param $1 string Pattern or full path (e.g. "*.log" or "~/.claude/.claude.json")
# @param $2 string Optional path to search in, default is current directory
# @param $3 string Optional file type: f (file), d (directory), l (symlink)
# @param $4 int    Optional max depth to search
# @example find_path "myfile.txt"
# @example find_path "*.log" /var/log
# @example find_path "*.conf" /etc f
# @example find_path "logs" . d
# @example find_path "*.txt" . f 2
# @example find_path ~/.claude/.claude.json
find_path() {
    local pattern="$1"
    local path="${2:-.}"
    local type="$3"
    local depth="$4"

    # ── Warn if pattern looks like it was glob-expanded ───────────────────────
    if [[ $# -gt 1 && "$2" != /* && "$2" != "." && "$2" != ".." && ! "$2" =~ ^[fdle]$ ]]; then
        echo -e "${STYLE[fg_yellow]}[!] Tip: use quotes to prevent glob expansion: fp \"${pattern}-*\"${STYLE[reset]}"
    fi

    # ── Auto-split full path into pattern + directory ─────────────────────────
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

# =========================
# --- Disk Utilities ---
# =========================

# @name disk_usage_top
# @description Display disk usage for a given path (default: $HOME),
#              showing top N largest entries (default: 20).
# @param $1 string Optional path to check, default is $HOME
# @param $2 int Optional number of entries to show, default is 20
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
#              - Clean npm & pnpm caches
#              - Clean package manager cache (dnf)
#              - Remove unused dependencies and old kernels
#              - (Optional) vacuum system logs
# @example clean_up_disk
clean_up_disk() {
    echo "Cleaning npm cache..."
    npm cache clean --force

    echo "Cleaning pnpm cache..."
    pnpm store prune

    echo "Cleaning package manager cache (dnf)..."
    sudo dnf clean all

    echo "Removing unused dependencies..."
    sudo dnf autoremove -y

    echo "Removing old kernels..."
    sudo dnf remove --oldinstallonly -y

#    echo "Vacuuming system logs..."
#    sudo journalctl --vacuum-size=500M

    echo "Disk cleanup completed"
    df -h
}
alias clean-up-disk='clean_up_disk'
alias cud='clean_up_disk'

# @name sys_update
# @description Update and upgrade system packages (supports apt and dnf).
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

# =========================
# --- Project Commands ---
# =========================

# Quickly change to uploads directory
alias cduploads='cd /srv/www/bidsystem/uploads/'

# @name run_project
# @description Run a pnpm script inside a specific project directory.
#              Avoid repetitive cd + pnpm commands, validate input,
#              and improve developer experience.
# @param $1 string Project directory name under ~/projects, default: "project"
# @param $2 string pnpm script name defined in package.json, default: "dev"
# @example run_project
# @example run_project dev <myproject>
# @example run_project start:prod <myproject>
run_project() {
    # Set default values if parameters are missing
    local script="${1:-dev}"
    local project="${2:-/etc/moneytek/construction_pmis}"

#    if [ -z "$1" ] || [ -z "$2" ]; then
#        echo "Usage: run_project <project> <pnpm-script>"
#        return 1
#    fi

    # Ensure target project exists before executing pnpm
    cd "$project" || {
        echo "Project not found: $project"
        return 1
    }

    echo "Running pnpm $script in $project"
    pnpm "$script"
}

# General alias to run project with parameters
alias run-prj='run_project'

# Aliases for a specific project (replace 'myproject' with your actual project name)
alias run-dev='run_project dev'
alias run-prj-dev='run_project dev'
alias run-prod='run_project start:prod'
alias run-prj-prod='run_project start:prod'
alias stop-dev='port=$(sss | grep 3001 | grep -oP "(?<=pid=)[0-9]+") && echo "Stopping Dev server on port 3001 (pid=${port})" && kill $port'


# =========================
# --- Package Utilities ---
# =========================

# @name pkg_installed
# @description Check if a package is installed (supports apt and dnf).
# @param $1 string Package name to check
# @example pkg_installed shfmt
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

    # ── Detect package manager ────────────────────────────────────────────────
    if command -v dnf &>/dev/null; then
        dnf list installed "$pkg" &>/dev/null
    elif command -v apt &>/dev/null; then
        dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"
    else
        echo -e "${BG_RED}[X]${RESET} ${FG_RED}No supported package manager found (apt/dnf)${RESET}"
        return 2
    fi

    # ── Result ────────────────────────────────────────────────────────────────
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
# @description Check if a package is installed, prompt to install if not (supports apt and dnf).
# @param $1 string Package name to check and optionally install
# @example pkg_ensure shfmt
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

    # ── Detect package manager ────────────────────────────────────────────────
    local mgr=""
    if command -v dnf &>/dev/null; then
        mgr="dnf"
    elif command -v apt &>/dev/null; then
        mgr="apt"
    else
        echo -e "${BG_RED}[X]${RESET} ${FG_RED}No supported package manager found (apt/dnf)${RESET}"
        return 2
    fi

    # ── Check if already installed ────────────────────────────────────────────
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

    # ── Prompt to install ─────────────────────────────────────────────────────
    echo -e "${BG_RED}[X]${RESET} ${FG_RED}${pkg} is not installed${RESET}"
    echo -e "${BG_YELLOW}[?]${RESET} ${FG_YELLOW}Install ${pkg} now? (y/N):${RESET} \c"
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
############################################################