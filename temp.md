```txt
/etc/profile.d/.alias/
├── .bash_env        # 環境變數、PATH 設定
├── .bash_functions  # 共用函數
├── .bash_git        # git 相關 alias / function
├── .bash_aliases    # alias 集中檔 (簡短快捷命令)
```


```/etc/bashrc
############################################################
[ -f ~/.alias/.bash_aliases ] && source ~/.alias/.bash_aliases

# Update PROMPT_COMMAND based on PS1 before showing the prompt
PROMPT_COMMAND=build_ps1
#build_ps1
############################################################
```



```/etc/profile.d/.alias/.bash_env
#!/usr/bin/env bash
# @file .bash_aliases
# @brief Bash prompt builder with full ANSI style support.
# @description
#   Provides a structured way to build PS1 prompts using named ANSI styles.
#   Covers font styles, foreground/background colors (standard + bright),
#   segment functions per prompt component, and a final PS1 assembler.

# ##############################################################################
# @section Style Map
# @description
#   Associative array of all supported ANSI escape sequences for use in PS1.
#   Keys are grouped into: reset, font styles, fg colors, bg colors.
#   All values are wrapped in \[...\] to prevent PS1 line-length miscalculation.
# ##############################################################################

declare -A STYLE=(
    # ── reset ─────────────────────────────────────────────────────────────────
    # [reset]=$'\e[0m'
    # [reset]='\[\e[0m\]'
    [reset]=$'\e[0m'

    # ── font styles ───────────────────────────────────────────────────────────
    [bold]=$'\e[1m'
    [dim]=$'\e[2m'
    [italic]=$'\e[3m'
    [underline]=$'\e[4m'
    [blink]=$'\e[5m'
    [reverse]=$'\e[7m'
    [strikethrough]=$'\e[9m'

    # ── foreground colors (standard) ──────────────────────────────────────────
    [fg_black]=$'\e[30m'
    [fg_red]=$'\e[31m'
    [fg_green]=$'\e[32m'
    [fg_yellow]=$'\e[33m'
    [fg_blue]=$'\e[34m'
    [fg_magenta]=$'\e[35m'
    [fg_cyan]=$'\e[36m'
    [fg_white]=$'\e[37m'

    # ── foreground colors (bright) ────────────────────────────────────────────
    [fg_bright_black]=$'\e[90m'
    [fg_bright_red]=$'\e[91m'
    [fg_bright_green]=$'\e[92m'
    [fg_bright_yellow]=$'\e[93m'
    [fg_bright_blue]=$'\e[94m'
    [fg_bright_magenta]=$'\e[95m'
    [fg_bright_cyan]=$'\e[96m'
    [fg_bright_white]=$'\e[97m'

    # ── background colors (standard) ──────────────────────────────────────────
    [bg_black]=$'\e[40m'
    [bg_red]=$'\e[41m'
    [bg_green]=$'\e[42m'
    [bg_yellow]=$'\e[43m'
    [bg_blue]=$'\e[44m'
    [bg_magenta]=$'\e[45m'
    [bg_cyan]=$'\e[46m'
    [bg_white]=$'\e[47m'

    # ── background colors (bright) ────────────────────────────────────────────
    [bg_bright_black]=$'\e[100m'
    [bg_bright_red]=$'\e[101m'
    [bg_bright_green]=$'\e[102m'
    [bg_bright_yellow]=$'\e[103m'
    [bg_bright_blue]=$'\e[104m'
    [bg_bright_magenta]=$'\e[105m'
    [bg_bright_cyan]=$'\e[106m'
    [bg_bright_white]=$'\e[107m'
)

# @name styled
# @description Apply STYLE attributes to a text string.
#              Defaults: text="" fg=fg_white bg="" st=""
# @param -t  | --text        string  Text to style (default: "")
# @param -fg | --foreground  string  Foreground color key from STYLE (default: fg_white)
# @param -bg | --background  string  Background color key from STYLE (default: none)
# @param -st | --style       string  Style key from STYLE (default: none)
# @example styled -t "\u"
# @example styled -t "\u" -fg fg_yellow -st bold
# @example styled -t "$ip" -fg fg_bright_white -bg bg_yellow -st bold
# @example styled --text "\W" --foreground fg_bright_white --style dim
styled() {
    local text=""
    local fg="${STYLE[fg_white]}"
    local bg=""
    local st=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t  | --text)       text="$2";           shift 2 ;;
            -fg | --foreground) fg="${STYLE[$2]}";   shift 2 ;;
            -bg | --background) bg="${STYLE[$2]}";   shift 2 ;;
            -st | --style)      st="${STYLE[$2]}";   shift 2 ;;
            *) shift ;;
        esac
    done

#    echo "${st:+${st}}${bg:+${bg}}${fg:+${fg}}${text}${STYLE[reset]}"
		local codes=""
    [[ -n "$st" ]] && codes+="\[${st}\]"
    [[ -n "$bg" ]] && codes+="\[${bg}\]"
    [[ -n "$fg" ]] && codes+="\[${fg}\]"

    echo "${codes}${text}\[${STYLE[reset]}\]"
}

# @name git_prompt
# @description Generate Git branch and status symbols for Bash prompt.
#              Symbols:
#              ✔ Clean working tree (nothing to commit)
#              ● Uncommitted changes (modified/deleted in working tree)
#              ✚ Staged changes (index modified)
#              ✖ Merge conflicts
#              ? Untracked files
#              ⚑ Stashed changes
#              ↑ Ahead of remote
#              ↓ Behind remote
#              ⇕ Diverged from remote
#              Detached HEAD shows short commit hash
#              Shows REBASE / MERGE when in progress
git_prompt() {
    command -v git >/dev/null 2>&1 || return
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return

    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || return

    local branch symbols=""

    # ── Short commit hash ─────────────────────────────────────────────────────
    local hash
    hash=$(git rev-parse --short=6 HEAD 2>/dev/null) || hash="unknown"

    # ── Detached HEAD ─────────────────────────────────────────────────────────
    if ! branch=$(git symbolic-ref --short HEAD 2>/dev/null); then
        local remote_branch
        remote_branch=$(git branch -r --points-at HEAD 2>/dev/null | grep -v '\->' | sed 's/^ *//' | head -n1)
        if [[ -n "$remote_branch" ]]; then
            branch="$remote_branch"
        else
            branch="detached:$hash"
        fi
    fi

    # ── Rebase / Merge in progress ───────────────────────────────────────────
    if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
        branch="$branch|REBASE"
    elif [[ -f "$git_dir/MERGE_HEAD" ]]; then
        branch="$branch|MERGE"
    fi

    # ── Git status ───────────────────────────────────────────────────────────
    local status
    status=$(git status --porcelain=v1 --branch 2>/dev/null) || return

    # Staged
    echo "$status" | grep -qE "^[MARCD]." && symbols+="✚"
    # Unstaged modified / deleted
    echo "$status" | grep -qE "^.[MD]"    && symbols+="●"
    # Merge conflicts
    echo "$status" | grep -qE "^(UU|AA|DD|AU|UA|DU|UD)" && symbols+="✖"
    # Untracked
    echo "$status" | grep -qE "^??"       && symbols+="?"

    # ── Ahead / Behind / Diverged ────────────────────────────────────────────
    local ahead behind
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null)
    behind=$(git rev-list --count HEAD..@{u} 2>/dev/null)

    if [[ "$ahead" -gt 0 && "$behind" -gt 0 ]]; then
        symbols+="⇕${ahead}↑${behind}↓"
    elif [[ "$ahead" -gt 0 ]]; then
#        symbols+="↑${ahead}"
        symbols+=$(styled -t "↑${ahead}" -fg fg_bright_green)
    elif [[ "$behind" -gt 0 ]]; then
#        symbols+="↓${behind}"
        symbols+=$(styled -t "↓${behind}" -fg fg_bright_red)
    fi

    # ── Stash ────────────────────────────────────────────────────────────────
    git stash list --format="%h" 2>/dev/null | grep -q . && symbols+="⚑"

    # ── Clean state ──────────────────────────────────────────────────────────
#    [[ -z "$symbols" ]] && symbols="✔"
    [[ -z "$symbols" ]] && symbols=$(styled -t "✔" -fg fg_bright_green)

#    echo "($branch[$hash]${symbols:+ $symbols})"

		local open='('
		branch=$(styled -t "[$branch]" -fg fg_bright_white -bg bg_yellow -st bold)
		hash=$(styled -t "$hash" -fg fg_yellow -st bold)
		local close=')'

		echo "${open}${branch} ${hash}${symbols:+ ${symbols}}${close}"

#    $(styled -t "$ip" -fg fg_bright_white -bg bg_yellow -st bold)
}

# @name build_ps1
# @description Build Bash prompt with user@host ip path git-status.
#              Colors: user:red host:yellow ip:cyan path:blue git:magenta
#              Layout example:
#              [root@host:192.168.1.10 ~/project (main abc123 ✔)]#
#              [user@host:192.168.1.10 ~/project (main abc123 ✔)]$
# @symbols
#              \u  → username 使用者名稱
#              \h  → hostname 主機名稱 (short)
#              \H  → hostname 主機名稱 (full)
#              \w  → full working directory path 當前工作目錄完整路徑
#              \W  → current directory name only 當前工作目錄最後一個目錄名稱
#              \$  → # for root, $ for normal users (auto) 普通使用者顯示 $，root 顯示 #
#- \! → 歷史命令編號
#- \d → 日期
#- \t → 時間 (HH:MM:SS)
#- \$ → $ 或 #（依使用者是否為 root）

# @depends     get_ip, git_prompt, STYLE
# @example     PROMPT_COMMAND='build_ps1'   # set in ~/.bashrc
# @example     build_ps1                    # manually trigger once
# @example     build_ps1                    # Directly sets the current shell prompt
# @example     source ~/.bashrc             # Ensures prompt is built on shell start
# @example     export PS1=$(build_ps1)      # Optional: force PS1 assignment manually
# @remark      Prototype: [root@sub construction_pmis]#
#              PS1 → 主要 prompt
#              PS2 → 多行命令續行
#              PS3 → select 命令 prompt
#              PS4 → 除錯 / set -x 前綴
# export PS1='[\u@\h \w]# '
# export PS1='[\u@\h:$get_ip \w ]# '
# export PS1='\[\e[1;32m\][\u@\h\[\e[0m\]:\[\e[1;34m\]$get_ip\[\e[0m\] \[\e[1;33m\]\w\[\e[0m\]]# '
# export PS1='\[\e[1;31m\]\u\[\e[0m\]@\[\e[1;33m\]\h\[\e[0m\] \[\e[1;36m\]$get_ip\[\e[0m\] \[\e[1;34m\]\w\[\e[0m\]\n\$ '
# export PS1=$(build_ps1)
build_ps1() {
    local user=$(styled -t "\u" -fg fg_yellow -st bold)
    local group=$(styled -t "$(id -gn)" -fg fg_bright_yellow)
    local host=$(styled -t "\h" -fg fg_bright_white -st dim)
    local path=$(styled -t "\W" -fg fg_bright_white)

    local ip=$(get_ip)
    [[ -n "$ip" ]] && ip=$(styled -t "$ip" -fg fg_bright_white -bg bg_yellow -st bold)

    local git_prompt=$(echo git_prompt)
#    [[ -n "$git_prompt" ]] && git_prompt=$(styled -t "$(git_prompt)" -fg fg_bright_yellow -st dim)
    [[ -n "$git_prompt" ]] && git_prompt=$(git_prompt)

    # Prompt symbol (# for root, $ for normal users)
    local symbol
    [[ $EUID -eq 0 ]] && \
        symbol=$(styled -t "#" -fg fg_bright_red -st bold) || \
        symbol=$(styled -t "\$" -fg fg_bright_white -st bold)
    PS1="[${user}($group)@${host}:${ip} ${path} ${git_prompt}]${symbol} "
}
```


```/etc/profile.d/.alias/.bash_git
# =========================
# --- Git Commands ---
# =========================

# Amend last commit without changing message
alias amend='git commit --amend --no-edit'
alias git-amend='amend'

# Fetch remote main branch and merge into current branch
# Consider using --ff-only to avoid unnecessary merge commits
alias gfm='git fetch origin main && git merge origin/main'
alias gpm='git pull origin main'
alias git-fetch-main='gfm'

# Fetch and prune origin remote branches
alias gfp='git fetch --prune'
# Fetch and prune all remotes
alias gfap='git fetch --all --prune'


# @name git_switch_and_pull
# @description Interactively select a branch (excluding current) and run git pull origin main.
#              Validates git repo, branch availability, and user input before switching.
# @example git_switch_and_pull
# @example gswp
git_switch_and_pull() {
    # Validate: must be inside a git repository
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "[ERROR] Not inside a git repository"
        return 1
    fi

    local current_branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)

    # Validate: must not be in detached HEAD state
    if [ -z "$current_branch" ]; then
        echo "[ERROR] Cannot determine current branch (detached HEAD?)"
        return 1
    fi

    # List all local branches except the current one
    local branches
    branches=$(git branch | grep -v "^\* " | sed 's/^[[:space:]]*//')

    # Validate: at least one other branch must exist
    if [ -z "$branches" ]; then
        echo "[WARN] No other branches available to switch (current: $current_branch)"
        return 1
    fi

    echo "[INFO] Current branch: $current_branch"
    echo "[INFO] Available branches:"

    # Build indexed list for user selection
    local i=1
    local branch_array=()
    while IFS= read -r branch; do
        echo "  $i) $branch"
        branch_array+=("$branch")
        ((i++))
    done <<< "$branches"

    echo ""
    read -rp "Select branch number (1-${#branch_array[@]}): " choice

    # Validate: input must be a positive integer
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        echo "[ERROR] Invalid input: not a number"
        return 1
    fi

    # Validate: input must be within valid range
    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#branch_array[@]}" ]; then
        echo "[ERROR] Invalid input: number out of range (1-${#branch_array[@]})"
        return 1
    fi

    local target_branch="${branch_array[$((choice - 1))]}"

    echo "[INFO] Switching to branch: $target_branch"
    git switch "$target_branch" || {
        echo "[ERROR] Failed to switch branch"
        return 1
    }

    echo "[INFO] Running git pull origin main..."
    git pull origin main || {
        echo "[ERROR] git pull failed"
        return 1
    }

    echo "[INFO] Done. Current branch: $(git symbolic-ref --short HEAD)"
}

alias gswp='git_switch_and_pull'

# @name git_push_current_branch
# @description Push current branch to origin with upstream tracking.
#              Shows current branch and asks for confirmation before pushing
#              to prevent accidental remote updates.
# @example git_push_current_branch
# @example gpcb
git_push_current_branch() {

    # Validate: must be inside a git repository
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "[ERROR] Not inside a git repository"
        return 1
    fi

    local current_branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)

    # Validate: avoid detached HEAD
    if [ -z "$current_branch" ]; then
        echo "[ERROR] Cannot determine current branch (detached HEAD?)"
        return 1
    fi

    echo "[INFO] Current branch: $current_branch"
    echo "[INFO] Command: git push -u origin $current_branch"
    echo ""

    read -rp "Proceed with push? (y/N): " confirm

    # Only explicit 'y' or 'Y' proceeds
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "[INFO] Push cancelled"
        return 0
    fi

    git push -u origin "$current_branch" || {
        echo "[ERROR] Push failed"
        return 1
    }

    echo "[INFO] Push completed"
}

alias gpcb='git_push_current_branch'


# @name git_checkout_remote
# @description List remote branches that don't exist locally,
#              let user select one, then fetch and switch to it.
# @example git_checkout_remote
# @example gcr
git_checkout_remote() {
    command -v git >/dev/null 2>&1 || return
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        echo "Not inside a git repository." >&2
        return 1
    }

    # ── Fetch latest remote info ──────────────────────────────────────────────
    echo "Fetching remote branches..."
    git fetch --all --prune 2>/dev/null

    # ── Get remote branches excluding locally existing ones ───────────────────
    local remote_branches local_branches available i=1
    remote_branches=$(git branch -r | grep -v '\->' | sed 's/^ *//' | sed 's|origin/||')
    local_branches=$(git branch | sed 's/^ *\** *//')

    available=()
    while IFS= read -r branch; do
        if ! echo "$local_branches" | grep -qx "$branch"; then
            available+=("$branch")
        fi
    done <<< "$remote_branches"

    # ── No branches available ─────────────────────────────────────────────────
    if [[ ${#available[@]} -eq 0 ]]; then
        echo "No remote-only branches found." >&2
        return 1
    fi

    # ── Display list ──────────────────────────────────────────────────────────
    echo ""
    echo "Available remote branches:"
    echo "──────────────────────────"
    for branch in "${available[@]}"; do
        printf "  [%d] %s\n" "$i" "$branch"
        (( i++ ))
    done
    echo ""

    # ── Prompt user to select ─────────────────────────────────────────────────
    local choice
    read -rp "Select branch number (1-${#available[@]}): " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || \
       [[ "$choice" -lt 1 ]] || \
       [[ "$choice" -gt ${#available[@]} ]]; then
        echo "Invalid selection." >&2
        return 1
    fi

    # ── Fetch and switch ──────────────────────────────────────────────────────
    local selected="${available[$((choice - 1))]}"
    echo ""
    echo "Switching to: $selected"
    git fetch origin "$selected"
    git switch -c "$selected" "origin/$selected"
}
alias gcr='git_checkout_remote'
```


```/etc/profile.d/.alias/.bash_aliases
[ -f /etc/profile.d/.alias/.bash_env ] && source /etc/profile.d/.alias/.bash_env
[ -f /etc/profile.d/.alias/.bash_git ] && source /etc/profile.d/.alias/.bash_git
[ -f /etc/profile.d/.alias/.bash_git ] && source /etc/profile.d/.alias/.bash_functions


# ~/.bashrc & source ~/.bashrc
# Documentation style: shdoc
# === Command Line / Vim / sed Examples ===

# --- sed Examples ---
# Delete lines 10–20 and line 24
#   `sed '10,20d;24d' file.txt`
# Delete lines 27–142 and line 143
#   `sed '27,142d;143d' file.txt`

# --- Vim Examples ---
# Delete lines:
#   `:%d`           # delete all lines
#   `:10,20d`       # delete lines 10–20
#   `:27,143d`      # delete lines 27–143
# Delete single line:
#   `:49d`          # line 49
# Line numbers:
#   `:set number`        # temporarily show
#   `:set nonumber`      # disable
#   `:set relativenumber`# show relative
# Search & replace:
#   `:50,100s/search_from/replace_to/gc`  # range, confirm each
#   `:%s/search_from/replace_to/gc`       # entire file, confirm each
#   `:s/search_from/replace_to/gc`        # current line, confirm each
# Syntax highlighting commands (Vim only):
#    - [x] :syntax on
#    - [x] :syntax off


```


```/etc/profile.d/.alias/.bash_functions
############################################################
# =========================
# --- System Utilities ---
# =========================

# List globally installed npm packages (depth 0) in JSON format
alias npmlsg='npm list -g --depth=0 --json'

# Show network connections and listening ports
alias netstats='netstat -tulpn'
alias sss='ss -tulpn'

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


############################################################
```