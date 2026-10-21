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
# @description Primary IPv4 address: the source address of the default route (iproute,
#              present on every target), else the first of `hostname -I` -- which minimal
#              RHEL-family images do not ship, and whose first address can be a docker
#              bridge. Empty when there is none; never fails, since the prompt calls it.
# @example get_ip
get_ip() {
    local ip=""
    if command -v ip &>/dev/null; then
        ip=$(ip -4 route get 1.1.1.1 2>/dev/null \
            | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }') || ip=""
    fi
    if [[ -z "$ip" ]]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}') || ip=""
    fi
    echo "$ip"
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
# @param -f | --full     flag  apt: full-upgrade, so updates that need a new package
#                              are installed too instead of kept back
# @example sup           # asks before upgrading
# @example sup -y        # unattended (sys-maint.sh)
sys_update() {
    local yes=0 dry=0 full=0 usage="usage: sys_update [-y] [-n] [-f]"
    while (( $# )); do
        case "$1" in
            -y | --yes)     yes=1 ;;
            -n | --dry-run) dry=1 ;;
            -f | --full)    full=1 ;;
            -h | --help)    echo "$usage"; return 0 ;;
            *) log_err "Unknown option: $1 -- ${usage}"; return 1 ;;
        esac
        shift
    done

    local -a refresh upgrade
    case "$PKG_MGR" in
        apt)
            local verb=upgrade
            (( full )) && verb="full-upgrade"
            refresh=(apt-get update)
            upgrade=(apt-get "$verb")
            (( yes )) && upgrade=(env DEBIAN_FRONTEND=noninteractive apt-get -y
                -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$verb")
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
# --- Release upgrades ---
# =========================
# os_upgrade is generic; what differs per distro lives in hooks named
#   _os_upgrade_<OS_ID>_<phase>       e.g. _os_upgrade_ubuntu_run
#   _os_upgrade_<OS_FAMILY>_<phase>   the fallback for a whole family
# with phases check (notes and blockers), run (the upgrade itself) and cleanup
# (after the reboot). A distro without a run hook has no in-place upgrade: os_upgrade
# refuses, and `os_upgrade backup` keeps what a reinstall needs. Adding a distro is
# adding its hooks here; os_upgrade itself does not change. Hooks see the caller's
# `dry` and `yes` and run root commands through _osu_do, so -n stays truthful.

# @name _osu_do
# @description Internal: run one command as root, or under os_upgrade -n only print it.
_osu_do() {
    if (( ${dry:-0} )); then
        printf '  would run: %s\n' "${SUDO:+$SUDO }$*"
        return 0
    fi
    log_step "Running: $*"
    $SUDO "$@"
}

# @name _osu_hook
# @description Internal: echo the hook for a phase -- the distro's own, else its
#              family's. Fails when there is none.
# @param $1 string  Phase: check | run | cleanup
_osu_hook() {
    local f
    for f in "_os_upgrade_${OS_ID//[^a-zA-Z0-9_]/_}_$1" "_os_upgrade_${OS_FAMILY}_$1"; do
        declare -F "$f" >/dev/null && { echo "$f"; return 0; }
    done
    return 1
}

# @name _osu_list
# @description Internal: print a heading and the lines from stdin, if there are any.
# @param $1 string  Heading, for log_warn
_osu_list() {
    local -a lines
    mapfile -t lines
    (( ${#lines[@]} )) || return 0
    log_warn "$1"
    printf '  %s\n' "${lines[@]}"
}

# @name _osu_reboot_pending
# @description Internal: succeed when the running kernel or libraries are older than
#              the installed ones, i.e. a reboot is due.
_osu_reboot_pending() {
    case "$PKG_MGR" in
        apt) [[ -e /var/run/reboot-required ]] ;;
        # needs-restarting (dnf-utils) exits 1 when a reboot is needed.
        dnf) command -v needs-restarting &>/dev/null && ! needs-restarting -r &>/dev/null ;;
        *)   return 1 ;;
    esac
}

# @name _osu_check
# @description Internal: what would stop a release upgrade, then the distro's notes.
# @returns 0 nothing in the way; 1 something to fix first
_osu_check() {
    local rc=0 free_gb hook
    log_head "Release upgrade: ${OS_ID} ${OS_VERSION}"
    if _osu_reboot_pending; then
        log_err "A reboot is pending -- reboot first, so the upgrade starts from the running system"
        rc=1
    fi
    free_gb=$(df -BG --output=avail / 2>/dev/null | tail -1 | tr -dc '0-9')
    if (( ${free_gb:-0} < OS_UPGRADE_MIN_FREE_GB )); then
        log_err "Only ${free_gb:-?} GB free on / (want ${OS_UPGRADE_MIN_FREE_GB}) -- clean_up_disk or disk_grow first"
        rc=1
    else
        log_ok "${free_gb} GB free on /"
    fi
    if [[ -n "${SSH_CONNECTION:-}" && -z "${TMUX:-}${STY:-}" ]]; then
        log_warn "Over SSH without tmux/screen: a dropped connection can stop the upgrade half way"
    fi
    if hook=$(_osu_hook check); then
        "$hook" || rc=1
    fi
    _osu_hook run >/dev/null || log_warn "No in-place upgrade for ${OS_ID}: reinstall, keeping 'os_upgrade backup'"
    return "$rc"
}

# @name _osu_backup
# @description Internal: save /etc and the hand-installed package list under
#              OS_UPGRADE_BACKUP_DIR/<id>-<version>-<time>, root-only.
_osu_backup() {
    local dest
    dest="${OS_UPGRADE_BACKUP_DIR}/${OS_ID}-${OS_VERSION}-$(date +%Y%m%d-%H%M%S)"
    local -a list
    case "$PKG_MGR" in
        apt) list=(apt-mark showmanual) ;;
        dnf) list=(dnf -q repoquery --userinstalled --qf '%{name}\n') ;;
        *)   log_err "No supported package manager (OS family: ${OS_FAMILY})"; return 1 ;;
    esac
    log_step "Backing up to ${dest}"
    _osu_do mkdir -p -m 700 "$dest" || return 1
    if (( dry )); then
        printf '  would run: %s > %s\n' "${list[*]}" "$dest/packages.txt"
    else
        "${list[@]}" | $SUDO tee "$dest/packages.txt" >/dev/null \
            || { log_err "Could not write the package list"; return 1; }
    fi
    _osu_do tar -czf "$dest/etc.tar.gz" -C / etc || { log_err "Could not archive /etc"; return 1; }
    (( dry )) && return 0
    log_ok "Backup in ${dest}: etc.tar.gz, packages.txt"
    log_info "/home, databases and service data are not in it -- copy them off this machine yourself"
}

# @name _osu_cleanup
# @description Internal: after the upgrade and its reboot -- the distro's own checks,
#              then clean_up_disk (autoremove, caches, old kernels).
_osu_cleanup() {
    if _osu_reboot_pending; then
        (( dry )) || { log_err "Reboot into the new release first, then run cleanup"; return 1; }
        log_warn "A reboot is pending (ignored for the dry run)"
    fi
    log_head "After the upgrade: ${OS_ID} ${OS_VERSION}"
    local hook
    if hook=$(_osu_hook cleanup); then
        "$hook" || return 1
    fi
    local -a flags=()
    (( dry )) && flags+=(-n)
    (( yes )) && flags+=(-y)
    clean_up_disk "${flags[@]}" || return 1
    if [[ -d "$OS_UPGRADE_BACKUP_DIR" ]]; then
        log_info "Pre-upgrade backups are in ${OS_UPGRADE_BACKUP_DIR} -- remove them once the new release has proven itself"
    fi
}

# ── Ubuntu: LTS to the next LTS with do-release-upgrade ─────────────────────

_os_upgrade_ubuntu_check() {
    local prompt
    prompt=$(sed -n 's/^Prompt=//p' /etc/update-manager/release-upgrades 2>/dev/null)
    case "${prompt:-lts}" in
        lts)   log_ok "Prompt=lts: goes to the next LTS (one at a time: 22.04 -> 24.04 -> 26.04)" ;;
        never) log_err "Prompt=never in /etc/update-manager/release-upgrades: upgrades are switched off"; return 1 ;;
        *)     log_warn "Prompt=${prompt}: goes to the next release, which may not be an LTS" ;;
    esac
    if (( dry )); then
        log_info "Would ask Ubuntu for a new release: do-release-upgrade -c"
    elif command -v do-release-upgrade &>/dev/null; then
        do-release-upgrade -c || log_warn "No new release offered to this machine yet"
    fi
    return 0
}

_os_upgrade_ubuntu_run() {
    local -a n=() cmd=(do-release-upgrade)
    (( dry )) && n=(-n)
    pkg_install "${n[@]}" update-manager-core || return 1
    # Without -y it asks its own questions (config files, restarts); over SSH it opens
    # a spare sshd on port 1022 and runs inside screen.
    (( yes )) && cmd+=(-f DistUpgradeViewNonInteractive)
    _osu_do "${cmd[@]}" || { log_err "do-release-upgrade failed -- see its message above, and /var/log/dist-upgrade/ if it got that far"; return 1; }
    (( dry )) || log_ok "Done. Reboot, then: os_upgrade cleanup"
}

# @name _osu_ubuntu_obsolete
# @description Internal: purge what the old release left installed -- packages in no
#              enabled source that do-release-upgrade itself logged as obsolete. The
#              rest of ?obsolete (a local .deb, a source the upgrade switched off) is
#              only listed. A package that still depends on an old one is kept: apt is
#              asked for a plan that keeps it ("name+"), which pulls in the new
#              release's replacement (libsysprof-4-dev -> libsysprof-capture-4-dev).
#              Without such a plan nothing is purged.
# @param $1 int  1 when the upgrade switched sources off: their packages are among
#                the obsolete ones, so everything is only listed
_osu_ubuntu_obsolete() {
    local switched_off="$1" logged p plan
    local -a obsolete old=() other=() extra=() keep=()
    mapfile -t obsolete < <(apt list '?obsolete' 2>/dev/null | awk -F/ 'NF > 1 { print $1 }')
    (( ${#obsolete[@]} )) || return 0
    if (( switched_off )); then
        printf '%s\n' "${obsolete[@]}" \
            | _osu_list "Installed, but in no enabled source -- re-enable the sources above first, then review each and apt purge <name>:"
        return 0
    fi
    # One "Obsolete:" line per upgrade run; the last is the upgrade just done.
    logged=$(grep -hs ' Obsolete: ' "$OS_UPGRADE_UBUNTU_LOG" | tail -1 | sed 's/.* Obsolete: //')
    for p in "${obsolete[@]}"; do
        if [[ " $logged " == *" $p "* ]]; then old+=("$p"); else other+=("$p"); fi
    done
    if (( ${#other[@]} )); then
        printf '%s\n' "${other[@]}" \
            | _osu_list "Installed, but in no enabled source and not from the old release -- review each, then apt purge <name>:"
    fi
    (( ${#old[@]} )) || return 0

    # Simulate, then ask whatever else the purge would take along to stay.
    plan=$(LC_ALL=C apt-get -s purge "${old[@]}" 2>&1)
    mapfile -t extra < <(awk '$1 == "Purg" || $1 == "Remv" { print $2 }' <<< "$plan" \
        | grep -vxF -f <(printf '%s\n' "${old[@]}"))
    if (( ${#extra[@]} )); then
        keep=("${extra[@]/%/+}")
        if plan=$(LC_ALL=C apt-get -s purge "${old[@]}" "${keep[@]}" 2>&1); then
            mapfile -t extra < <(awk '$1 == "Purg" || $1 == "Remv" { print $2 }' <<< "$plan" \
                | grep -vxF -f <(printf '%s\n' "${old[@]}"))
        fi
        if (( ${#extra[@]} )) || grep -q '^E:' <<< "$plan"; then
            log_warn "Purging the old release's packages would also remove packages still in use, and apt finds no way to keep them:"
            printf '  %s\n' "${keep[@]%+}"
            printf '%s\n' "${old[@]}" \
                | _osu_list "Left over from the old release -- review each, then apt purge <name>:"
            return 0
        fi
    fi
    log_info "${#old[@]} package(s) left over from the old release -- simulated purge:"
    awk '$1 == "Purg" || $1 == "Remv" { print "  remove   " $2 }
         $1 == "Inst" { print "  install  " $2 }' <<< "$plan"
    if (( dry )) || confirm "Purge them?"; then
        _osu_do env DEBIAN_FRONTEND=noninteractive apt-get purge -y "${old[@]}" "${keep[@]}"
    fi
    return 0
}

_os_upgrade_ubuntu_cleanup() {
    # The upgrade switches third-party sources off rather than guess whether they
    # have a build for the new release.
    local switched_off=0
    grep -lsE 'disabled on upgrade|^Enabled: *no' /etc/apt/sources.list.d/* \
        | _osu_list "Sources the upgrade switched off -- re-enable each once it supports the new release:"
    grep -qsE 'disabled on upgrade|^Enabled: *no' /etc/apt/sources.list.d/* && switched_off=1
    if command -v apt &>/dev/null; then
        _osu_ubuntu_obsolete "$switched_off"
    fi
    find /etc \( -name '*.dpkg-dist' -o -name '*.dpkg-old' -o -name '*.ucf-dist' \
        -o -name '*.ucf-old' -o -name '*.distUpgrade' \) 2>/dev/null \
        | _osu_list "Config files set aside by the upgrade -- merge or delete each:"
    local -a leftover
    mapfile -t leftover < <(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null | awk '$1 == "rc" { print $2 }')
    (( ${#leftover[@]} )) || return 0
    log_info "${#leftover[@]} removed package(s) left config files behind:"
    printf '%s ' "${leftover[@]}" | fmt -w 96 | sed 's/^/  /'
    if (( dry )) || confirm "Purge those config files?"; then
        _osu_do env DEBIAN_FRONTEND=noninteractive apt-get purge -y "${leftover[@]}"
    fi
    return 0
}

# ── RHEL family: no run hook -- Rocky and Alma do not support it, RHEL uses leapp ──

_os_upgrade_rhel_check() {
    local next=$(( OS_MAJOR + 1 )) rc=0
    if [[ "$(uname -m)" == x86_64 ]] && (( next >= 10 )); then
        if /lib64/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q 'x86-64-v3 (supported'; then
            log_ok "The CPU has x86-64-v3, which EL${next} needs"
        else
            log_err "No x86-64-v3 on this CPU (or VM CPU model): RHEL/Rocky ${next} will not run here; AlmaLinux ${next} has an x86-64-v2 build"
            rc=1
        fi
    fi
    if [[ "$OS_ID" == rhel ]]; then
        log_info "Red Hat upgrades in place with leapp (dnf install leapp-upgrade; leapp preupgrade) -- not automated here"
    fi
    return "$rc"
}

_os_upgrade_rhel_cleanup() {
    # After a leapp or ELevate upgrade, or a restore onto a fresh install.
    local prev=$(( OS_MAJOR - 1 ))
    rpm -qa 2>/dev/null | grep -E "\.el${prev}([._]|$)" | sort \
        | _osu_list "Packages still from EL${prev} -- update or remove each:"
    find /etc \( -name '*.rpmnew' -o -name '*.rpmsave' \) 2>/dev/null \
        | _osu_list "Config files set aside by rpm -- merge or delete each:"
    return 0
}

# @name os_upgrade
# @description Upgrade to the next major release of the distro, in steps:
#                check    what would stop it (pending reboot, disk space, distro
#                         notes such as Ubuntu's Prompt= or EL10's CPU level)
#                backup   /etc and the hand-installed package list, root-only, in
#                         OS_UPGRADE_BACKUP_DIR
#                run      check, sys_update, backup, then the distro's upgrade
#                cleanup  after the reboot: what the upgrade set aside or switched
#                         off, the old release's packages (Ubuntu), leftover config
#                         files, then clean_up_disk
#              Ubuntu upgrades in place (do-release-upgrade, LTS to LTS). Rocky and
#              Alma have no supported in-place path: run refuses, and backup is
#              what the reinstall needs. Other distros: add hooks (see above).
# @param -n | --dry-run  flag    Show what would run, change nothing
# @param -y | --yes      flag    Answer yes; on Ubuntu, a non-interactive upgrade
# @param $1              string  check | backup | run | cleanup (default: a menu)
# @example os-upgrade check
# @example os-upgrade -n run      # the whole plan, nothing changed
# @example os-upgrade cleanup     # after the reboot
os_upgrade() {
    local dry=0 yes=0 action="" usage="usage: os_upgrade [-n] [-y] check|backup|run|cleanup"
    while (( $# )); do
        case "$1" in
            -n | --dry-run) dry=1 ;;
            -y | --yes)     yes=1 ;;
            -h | --help)    echo "$usage"; return 0 ;;
            check | backup | run | cleanup) action="$1" ;;
            *) log_err "Unknown argument: $1 -- ${usage}"; return 1 ;;
        esac
        shift
    done
    if [[ -z "$action" ]]; then
        ui_tty || { log_err "$usage"; return 1; }
        local -a actions=(check backup run cleanup)
        local pick
        radioselect pick "Release upgrade (${OS_ID} ${OS_VERSION}):" -1 \
            "check    what would stop an upgrade" \
            "backup   save /etc and the package list" \
            "run      upgrade to the next release" \
            "cleanup  after the upgrade and its reboot" || return 1
        action="${actions[$pick]}"
    fi
    local UI_ASSUME_YES="$UI_ASSUME_YES"
    (( yes )) && UI_ASSUME_YES=1

    case "$action" in
        check)   _osu_check ;;
        backup)  _osu_backup ;;
        cleanup) _osu_cleanup ;;
        run)
            if ! _osu_check; then
                (( dry )) || { log_err "Fix the above first"; return 1; }
                log_warn "Continuing the dry run despite the above"
            fi
            local hook
            hook=$(_osu_hook run) || {
                log_err "No in-place upgrade for ${OS_ID} ${OS_VERSION} -- 'os_upgrade backup' keeps what a reinstall needs"
                return 1
            }
            (( dry )) || confirm "Upgrade ${OS_ID} ${OS_VERSION} to the next release now?" \
                || { log_step "Cancelled"; return 1; }
            local -a flags=()
            (( dry )) && flags+=(-n)
            (( yes )) && flags+=(-y)
            # --full: do-release-upgrade refuses while any update is kept back.
            sys_update --full "${flags[@]}" || return 1
            _osu_backup || return 1
            "$hook"
            ;;
    esac
}
alias os-upgrade='os_upgrade'

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
