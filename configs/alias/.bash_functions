#!/usr/bin/env bash
# @file .bash_functions
# @brief Everyday system helpers: shell, listing, services, time, files, memory,
#        updates, and project dev servers.
# @description
#   Depends on .bash_env (globals, log_*) and .bash_ui (menus, confirm, ask).
#   Package handling lives in .bash_pkg, disks in .bash_disk, git in .bash_git.

# =========================
# --- Shell ---
# =========================

HISTCONTROL=ignoreboth          # skip duplicates and lines starting with a space
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize 2>/dev/null

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias less='less -R'            # pass ANSI colors through instead of showing escapes
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -alF'
alias la='ls -A'

# Jump to where the dotfiles live on this host
alias cdaliases='cd "$ALIAS_DIR"'
alias cdsbin='cd "$SBIN_DIR"'
alias cddotfiles='cd "${DOTFILES_ROOT:-$HOME/dotfiles}"'

# @name dotfiles
# @description Run the dotfiles installer from the checkout this host was deployed
#              from (DOTFILES_ROOT, written into the bashrc hook at deploy time), as
#              root. Arguments pass straight through; none opens the module menu.
# @param $@ string  install.sh arguments: modules, -n, -y, --list, -h
# @example dotfiles              # module menu
# @example dotfiles shell        # redeploy this library after editing the checkout
# @example dotfiles -n --all     # what a full run would do, changing nothing
dotfiles() {
    local root="${DOTFILES_ROOT:-}"
    if [[ -z "$root" || ! -f "$root/install.sh" ]]; then
        log_err "DOTFILES_ROOT is unset or has no install.sh -- run install.sh from your checkout once"
        return 1
    fi
    $SUDO bash "$root/install.sh" "$@"
}

# @name reload_shell
# @description Re-source the system bashrc (SYS_BASHRC), which reloads this library
#              through the dotfiles hook.
# @example rs
reload_shell() {
    if [[ -f "$SYS_BASHRC" ]]; then
        # shellcheck disable=SC1090
        source "$SYS_BASHRC" && log_ok "Reloaded ${SYS_BASHRC}"
    else
        log_warn "${SYS_BASHRC} not found -- try: source ~/.bashrc"
        return 1
    fi
}
alias reload-shell='reload_shell'
alias rs='reload_shell'

# =========================
# --- Listing / network / services ---
# =========================

alias lh='ls -lah'
alias lhu='lh -u'               # by access time
alias lhc='lh -c'               # by change time
alias lhs='lh -S'               # by size
alias lhx='lh -X'               # by extension
alias lht='lh -t'               # newest first
alias lhtr='lh -tr'             # newest last

alias netstats='netstat -tulpn'
alias sss='ss -tulpn'

# @name get_ip
# @description Primary IPv4 address (first of hostname -I); empty when there is none.
# @example get_ip
get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}
alias get-ip='get_ip'

alias svc-running='systemctl list-units --type=service --state=running'
alias svc-failed='systemctl list-units --type=service --state=failed'
alias svc-all='systemctl list-units --type=service --all'
alias svc-count='systemctl list-units --type=service --all | grep -c .service'
alias svc-status='systemctl status'

# =========================
# --- Date / time ---
# =========================

alias now='date "$NOW_FMT"'
alias today='date +"%Y-%m-%d"'
alias time-now='date +"%H:%M:%S"'

# @name _ntp_service
# @description Internal: echo the active NTP daemon -- chronyd (RHEL family default)
#              or systemd-timesyncd (Ubuntu default); return 1 when neither runs.
_ntp_service() {
    local svc
    for svc in chronyd systemd-timesyncd; do
        systemctl is-active --quiet "$svc" 2>/dev/null && { echo "$svc"; return 0; }
    done
    return 1
}

# @name ntp_sync
# @description Re-sync the clock by restarting whichever NTP daemon is active, then
#              show its tracking state. Non-interactive: safe from cron (ntp-sync.sh).
# @example ntp-sync
ntp_sync() {
    local svc
    svc=$(_ntp_service) || { log_err "No active NTP service found (chronyd / systemd-timesyncd)"; return 1; }
    log_warn "Restarting ${svc}..."
    $SUDO systemctl restart "$svc" || { log_err "Failed to restart ${svc}"; return 1; }
    sleep 2
    log_ok "${svc} restarted"
    if [[ "$svc" == chronyd ]]; then chronyc tracking; else timedatectl timesync-status 2>/dev/null; fi
    timedatectl status
}
alias ntp-sync='ntp_sync'

# @name ntp_status
# @description Clock and NTP state: timedatectl, plus the active daemon's own view.
# @example ntp-status
ntp_status() {
    timedatectl status
    echo ""
    case "$(_ntp_service)" in
        chronyd)           chronyc tracking ;;
        systemd-timesyncd) timedatectl timesync-status ;;
        *)                 log_warn "No active NTP service (chronyd / systemd-timesyncd)" ;;
    esac
}
alias ntp-status='ntp_status'

# @name ntp_fix
# @description Turn NTP on (timedatectl set-ntp true), restart the active daemon and
#              show the result. For a clock that drifted because NTP was off.
# @example ntp-fix
ntp_fix() {
    $SUDO timedatectl set-ntp true || { log_err "timedatectl set-ntp true failed"; return 1; }
    local svc
    svc=$(_ntp_service) || { log_err "NTP enabled, but no NTP daemon is running"; return 1; }
    $SUDO systemctl restart "$svc" && sleep 3
    timedatectl status
}
alias ntp-fix='ntp_fix'

# @name tz
# @description Show or set the timezone. An exact zone is set at once; a partial one
#              opens a menu of matches; none opens a menu of common zones (plus
#              manual entry). -l lists every zone matching the argument and stops.
# @param -l | --list  flag    List matching zones only, change nothing
# @param $1           string  Optional exact zone or keyword (Asia/Taipei, Asia, tokyo)
# @example tz                 # menu of common zones
# @example tz Asia/Taipei     # set directly
# @example tz tokyo           # menu of matches
# @example tz -l europe       # list only
tz() {
    local list=0 query="" usage="usage: tz [-l] [zone-or-keyword]"
    while (( $# )); do
        case "$1" in
            -l | --list) list=1 ;;
            -h | --help) echo "$usage"; return 0 ;;
            -*) log_err "Unknown option: $1 -- ${usage}"; return 1 ;;
            *)  query="$1" ;;
        esac
        shift
    done
    local -a zones=() common=(
        Asia/Taipei Asia/Tokyo Asia/Shanghai Asia/Singapore Asia/Seoul UTC
        Europe/London Europe/Paris America/New_York America/Los_Angeles
    )
    mapfile -t zones < <(timedatectl list-timezones 2>/dev/null)

    if (( list )); then
        printf '%s\n' "${zones[@]}" | grep -i -- "${query:-.}"
        return 0
    fi

    local pick zone=""
    if [[ -n "$query" ]]; then
        if printf '%s\n' "${zones[@]}" | grep -qx -- "$query"; then
            zone="$query"
        else
            local -a matches
            mapfile -t matches < <(printf '%s\n' "${zones[@]}" | grep -i -- "$query")
            (( ${#matches[@]} )) || { log_err "No timezone matches: ${query}"; return 1; }
            ui_tty || { printf '%s\n' "${matches[@]}"; log_err "Several zones match -- give one exactly"; return 1; }
            radioselect pick "Zones matching '${query}':" -1 "${matches[@]}" || { log_info "Cancelled"; return 0; }
            zone="${matches[$pick]}"
        fi
    else
        log_step "Current timezone:"
        timedatectl | grep -E "Local time|Time zone"
        ui_tty || return 0
        echo ""
        radioselect pick "Set timezone:" -1 "${common[@]}" "Enter manually..." || { log_info "Cancelled"; return 0; }
        if (( pick == ${#common[@]} )); then
            ask zone "Timezone (e.g. Asia/Taipei)" || return 1
            [[ -n "$zone" ]] || { log_info "Cancelled"; return 0; }
            printf '%s\n' "${zones[@]}" | grep -qx -- "$zone" || { log_err "Unknown timezone: ${zone}"; return 1; }
        else
            zone="${common[$pick]}"
        fi
    fi

    $SUDO timedatectl set-timezone "$zone" || { log_err "Failed to set ${zone}"; return 1; }
    log_ok "Timezone set to: ${zone}"
    timedatectl | grep -E "Local time|Time zone"
}

# =========================
# --- Files ---
# =========================

# @name find_path
# @description Find files or directories by name (like fd). $1 may hold several
#              whitespace-separated patterns (spaces, tabs or newlines), OR'd in one
#              find pass -- quote it, or the shell expands the globs first. A single
#              pattern containing / is split into directory + name.
# @param $1 string One or more patterns, or a full path ("*.log", "a* b*", ~/x/y.json)
# @param $2 string Optional directory to search (default: .)
# @param $3 string Optional type: f (file), d (directory), l (symlink)
# @param $4 int    Optional max depth
# @example fp "*.log" /var/log
# @example fp "fileA* fileB*" . f 2
# @example fp ~/.claude/.claude.json
find_path() {
    local pattern="${1:-}" path="${2:-.}" type="${3:-}" depth="${4:-}"

    if [[ $# -gt 1 && "$2" != /* && "$2" != "." && "$2" != ".." && ! "$2" =~ ^[fdle]$ ]]; then
        log_warn "Use quotes to prevent glob expansion: fp \"${pattern}-*\""
    fi

    # read -a splits on IFS without globbing; -d '' reads to EOF so a multi-line
    # pattern list works too (it returns 1 at EOF, hence || true).
    local -a patterns
    read -r -d '' -a patterns <<< "$pattern" || true
    if [[ ${#patterns[@]} -eq 0 ]]; then
        log_err "usage: find_path \"<pattern> [pattern...]\" [path] [type] [depth]"
        return 1
    fi

    if [[ ${#patterns[@]} -eq 1 && "${patterns[0]}" == */* ]]; then
        path=$(dirname "${patterns[0]}")
        patterns[0]=$(basename "${patterns[0]}")
    fi

    local -a name_expr=() args=()
    local p
    for p in "${patterns[@]}"; do
        [[ ${#name_expr[@]} -gt 0 ]] && name_expr+=(-o)
        name_expr+=(-name "$p")
    done
    # -maxdepth is an option, so it must precede any test
    [[ -n "$depth" ]] && args+=(-maxdepth "$depth")
    [[ -n "$type" ]]  && args+=(-type "$type")

    local results
    results=$(find "$path" "${args[@]}" \( "${name_expr[@]}" \) 2>/dev/null)
    if [[ -z "$results" ]]; then
        log_err "No matches found for: ${patterns[*]}"
        return 1
    fi
    log_ok "Found the following matches:"
    echo -e "${STYLE[fg_bright_green]}${results}${STYLE[reset]}"

    # Patterns that contributed nothing: classify the one find pass rather than
    # re-running find per pattern ($p unquoted = glob match, as find -name does).
    if [[ ${#patterns[@]} -gt 1 ]]; then
        local -a missing=()
        local line hit
        for p in "${patterns[@]}"; do
            hit=""
            while IFS= read -r line; do
                # shellcheck disable=SC2053
                [[ "${line##*/}" == $p ]] && { hit=1; break; }
            done <<< "$results"
            [[ -z "$hit" ]] && missing+=("$p")
        done
        (( ${#missing[@]} )) && log_warn "No matches for: ${missing[*]}"
    fi
    return 0
}
alias find-path='find_path'
alias fp='find_path'

# =========================
# --- Memory ---
# =========================

# @name free_mem
# @description Flush dirty pages and drop the kernel's page/dentry/inode caches, then
#              report what was reclaimed. Cached memory is not wasted -- the kernel
#              reuses it on demand -- and a forced drop briefly slows I/O while the
#              caches warm up again. Standard kernel interface, any distro.
# @example fm
free_mem() {
    local before after
    before=$(free -m | awk '/^Mem:/ {print $7}')
    log_step "Memory before release:"
    free -h
    log_warn "Syncing and dropping caches..."
    sync
    echo 3 | $SUDO tee /proc/sys/vm/drop_caches >/dev/null || { log_err "Failed to drop caches (needs root)"; return 1; }
    after=$(free -m | awk '/^Mem:/ {print $7}')
    echo ""
    log_step "Memory after release:"
    free -h
    echo ""
    log_ok "Reclaimed $(( after - before )) MB (available: ${before} MB -> ${after} MB)"
}
alias free-mem='free_mem'
alias fm='free_mem'

# =========================
# --- System updates ---
# =========================

# @name sys_update
# @description Refresh the package index and upgrade every package (PKG_MGR). Without
#              -y the package manager asks its own question; with -y nothing asks --
#              on apt that includes keeping the current version of a changed config
#              file, which is what an unattended cron run needs (an interactive dpkg
#              conffile prompt would hang it).
# @param -y | --yes      flag  Fully non-interactive
# @param -n | --dry-run  flag  Print the commands, run nothing
# @example sup           # asks before upgrading
# @example sup -y        # unattended (sys-maint.sh)
sys_update() {
    local yes=0 dry=0 usage="usage: sys_update [-y] [-n]"
    while (( $# )); do
        case "$1" in
            -y | --yes)     yes=1 ;;
            -n | --dry-run) dry=1 ;;
            -h | --help)    echo "$usage"; return 0 ;;
            *) log_err "Unknown option: $1 -- ${usage}"; return 1 ;;
        esac
        shift
    done

    local -a refresh upgrade
    case "$PKG_MGR" in
        apt)
            refresh=(apt-get update)
            upgrade=(apt-get upgrade)
            (( yes )) && upgrade=(env DEBIAN_FRONTEND=noninteractive apt-get -y
                -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade)
            ;;
        dnf)
            refresh=(dnf makecache)
            upgrade=(dnf upgrade)
            (( yes )) && upgrade=(dnf -y upgrade)
            ;;
        *) log_err "No supported package manager (OS family: ${OS_FAMILY})"; return 1 ;;
    esac

    if (( dry )); then
        log_info "Dry run -- would run:"
        printf '  %s\n' "${SUDO:+$SUDO }${refresh[*]}" "${SUDO:+$SUDO }${upgrade[*]}"
        return 0
    fi
    log_info "Updating via ${PKG_MGR}..."
    $SUDO "${refresh[@]}" && $SUDO "${upgrade[@]}"
}
alias sys-update='sys_update'
alias sup='sys_update'

# @name sys_maintain
# @description sys_update, then clean_up_disk (.bash_disk), with the same flags.
#              /usr/local/sbin/sys-maint.sh runs `sys_maintain -y` from cron daily.
# @param -y | --yes      flag  Fully non-interactive
# @param -n | --dry-run  flag  Show what would run, change nothing
# @example sys-maint -n
sys_maintain() {
    sys_update "$@" && clean_up_disk "$@"
}
alias sys-maint='sys_maintain'

# =========================
# --- Project dev servers ---
# =========================

# @name run_project
# @description Run a package.json script with pnpm in a project directory, from
#              anywhere. Directory: -d, else the second argument, else
#              RUN_PROJECT_DIR (set it in .bash_local), else the current directory.
#              With no script given, pick one from the project's package.json.
# @param -d | --dir  string  Project directory
# @param $1          string  pnpm script name (default: pick from a menu)
# @param $2          string  Project directory (same as -d)
# @example run_project dev
# @example run_project start:prod /srv/app
# @example run-prj            # menu of the project's scripts
run_project() {
    local script="" dir="" usage="usage: run_project [-d dir] [script] [dir]"
    while (( $# )); do
        case "$1" in
            -d | --dir)  dir="${2:-}"; shift ;;
            -h | --help) echo "$usage"; return 0 ;;
            -*) log_err "Unknown option: $1 -- ${usage}"; return 1 ;;
            *)  if [[ -z "$script" ]]; then script="$1"; else dir="$1"; fi ;;
        esac
        shift
    done
    dir="${dir:-${RUN_PROJECT_DIR:-$PWD}}"
    [[ -f "$dir/package.json" ]] || { log_err "No package.json in ${dir} -- pass -d <dir> or set RUN_PROJECT_DIR"; return 1; }

    if [[ -z "$script" ]]; then
        ui_tty || { log_err "$usage"; return 1; }
        command -v jq &>/dev/null || { log_err "Need a script name (or jq, to list them): ${usage}"; return 1; }
        local -a scripts
        local pick
        mapfile -t scripts < <(jq -r '.scripts // {} | keys[]' "$dir/package.json")
        (( ${#scripts[@]} )) || { log_err "No scripts in ${dir}/package.json"; return 1; }
        radioselect pick "Run which script in ${dir}?" -1 "${scripts[@]}" || { log_info "Cancelled"; return 0; }
        script="${scripts[$pick]}"
    fi
    log_info "Running pnpm ${script} in ${dir}"
    ( cd "$dir" && pnpm "$script" )
}
alias run-prj='run_project'
alias run-dev='run_project dev'
alias run-prod='run_project start:prod'

# @name _listening_ports
# @description Internal: one "<port>\t<pid>\t<command>" line per TCP listener whose
#              process is visible (your own, or everyone's as root).
_listening_ports() {
    ss -tlnpH 2>/dev/null | awk '{
        n = split($4, a, ":"); port = a[n]
        if (match($0, /pid=[0-9]+/)) {
            pid = substr($0, RSTART + 4, RLENGTH - 4)
            cmd = "?"; if (match($0, /\(\("[^"]+"/)) cmd = substr($0, RSTART + 3, RLENGTH - 4)
            print port "\t" pid "\t" cmd
        }
    }' | sort -u -n
}

# @name stop_dev
# @description Stop the process listening on a TCP port: SIGTERM, or SIGKILL with -9.
#              With no port, pick from the listening processes (3001 highlighted when
#              present); with no terminal, port 3001.
# @param $1          int   Optional port (default: menu, or 3001 without a terminal)
# @param -9          flag  SIGKILL instead of SIGTERM
# @example stop-dev            # menu of listening processes
# @example stop-dev 3002 -9
stop_dev() {
    local port="" sig="TERM" usage="usage: stop_dev [port] [-9]"
    while (( $# )); do
        case "$1" in
            -9)          sig="KILL" ;;
            -h | --help) echo "$usage"; return 0 ;;
            *[!0-9]*)    log_err "Not a port: $1 -- ${usage}"; return 1 ;;
            *)           port="$1" ;;
        esac
        shift
    done

    local -a rows
    mapfile -t rows < <(_listening_ports)
    if [[ -z "$port" ]]; then
        if ui_tty && (( ${#rows[@]} )); then
            local -a labels=()
            local row p pid cmd cur=-1 pick i=0
            for row in "${rows[@]}"; do
                IFS=$'\t' read -r p pid cmd <<< "$row"
                [[ "$p" == 3001 ]] && cur=$i
                labels+=("$(printf '%-6s %s (pid %s)' "$p" "$cmd" "$pid")")
                (( i++ ))
            done
            radioselect pick "Stop which listener?" "$cur" "${labels[@]}" || { log_info "Cancelled"; return 0; }
            port=$(cut -f1 <<< "${rows[$pick]}")
        else
            port=3001
        fi
    fi

    local pid
    pid=$(printf '%s\n' "${rows[@]}" | awk -F'\t' -v p="$port" '$1 == p {print $2; exit}')
    if [[ -z "$pid" ]]; then
        log_info "No visible process listening on port ${port}"
        return 1
    fi
    log_info "Sending SIG${sig} to pid ${pid} (port ${port})"
    kill -s "$sig" "$pid"
}
alias stop-dev='stop_dev'
