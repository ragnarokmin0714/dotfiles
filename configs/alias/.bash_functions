############################################################
# =========================
# --- Shell Config ---
# =========================

# Reload bash configuration
alias srcbash='source /etc/bashrc && source ~/.bashrc'
# Navigate to alias profile directory
alias cdaliases='cd /etc/profile.d/.alias'
# Quickly change to uploads directory
alias cduploads='cd /srv/www/bidsystem/uploads/'
# Quickly change to construction_pmis directory
alias cdpmis='cd /etc/moneytek/construction_pmis'
# change directory to moneytek log directory
alias cdlog='cd /var/log/moneytek'
# change directory to local sbin directory
alias cdsbin='cd /usr/local/sbin'

# @name deploy_alias
# @description Sync alias scripts from a working copy to ALIAS_DST_DIR, normalize
#              perms to 644, and reload the current shell. Paths come from the
#              ALIAS_SRC_DIR / ALIAS_DST_DIR constants (.bash_env), so a distro with a
#              different layout only overrides those (e.g. ALIAS_DST_DIR=...).
# @param $1 string Source dir (default: $ALIAS_SRC_DIR from .bash_env)
# @example deploy_alias
# @example deploy_alias /path/to/alias
deploy_alias() {
    local src="${1:-$ALIAS_SRC_DIR}"
    local dst="$ALIAS_DST_DIR"

    sudo mkdir -p "$dst" || { log_err "Failed to create ${dst}"; return 1; }
    sudo install -m 644 "$src"/.bash_* "$dst"/ || {
        log_err "Failed to deploy alias scripts from ${src} to ${dst}"
        return 1
    }
    log_ok "Deployed .alias scripts: ${src} -> ${dst} (chmod 644)"
    # shellcheck disable=SC1091
    source "$dst/.bash_aliases" && log_ok "Reloaded current shell"
}
alias deploy-alias='deploy_alias'

# @name ensure_alias_hook
# @description Idempotently make the system-wide bashrc (ALIAS_HOOK_FILE) source
#              ALIAS_DST_DIR/.bash_aliases, so a fresh host loads the alias system on
#              next login. Safe to re-run: appends the line only if absent. The hook
#              file differs by distro (/etc/bashrc vs /etc/bash.bashrc) and is resolved
#              from /etc/os-release in .bash_env.
# @example ensure_alias_hook && deploy_alias   # first-time setup on a new host
ensure_alias_hook() {
    local hook="$ALIAS_HOOK_FILE"
    local marker="$ALIAS_DST_DIR/.bash_aliases"
    local line="[ -f $marker ] && source $marker"
    [ -n "$hook" ] || { log_err "ensure_alias_hook: ALIAS_HOOK_FILE is empty"; return 1; }
    if [ -f "$hook" ] && grep -qF "$marker" "$hook"; then
        log_info "alias hook already present in ${hook}"
        return 0
    fi
    echo "$line" | sudo tee -a "$hook" >/dev/null || {
        log_err "ensure_alias_hook: failed to write ${hook}"
        return 1
    }
    log_ok "added alias hook to ${hook}"
}
alias ensure-alias-hook='ensure_alias_hook'

# =========================
# --- Pager ---
# =========================

# Enable ANSI color codes in less (prevents color escape sequences showing as raw text)
alias less='less -R'

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

# current datetime in YYYY-MM-DD HH:MM:SS format (NOW_FMT shared with log_* in .bash_env)
alias now='date "$NOW_FMT"'
# current date in YYYY-MM-DD format
alias today='date +"%Y-%m-%d"'
# current time in HH:MM:SS format
alias time-now='date +"%H:%M:%S"'

## Enable NTP and restart time sync service
#alias ntp-sync='sudo chronyc makestep && sudo hwclock --systohc && chronyc tracking && timedatectl'

# @name ntp_sync
# @description Re-sync system time using the active NTP service.
#              Auto-detects chronyd (Rocky Linux / RHEL) or
#              systemd-timesyncd (Ubuntu / Debian).
# @depends     systemctl, chronyc, timedatectl
# @example     ntp_sync
# @example     ntp-sync
ntp_sync() {
    if systemctl is-active --quiet chronyd; then
        # ── Rocky Linux / RHEL-based ──────────────────────────────────────────
        log_warn "Restarting chronyd..."
        sudo systemctl restart chronyd || {
            log_err "Failed to restart chronyd"
            return 1
        }
        sleep 2
        log_ok "chronyd restarted successfully"
        echo ""
        chronyc tracking
        echo ""
        timedatectl

    elif systemctl is-active --quiet systemd-timesyncd; then
        # ── Ubuntu / Debian-based ─────────────────────────────────────────────
        log_warn "Restarting systemd-timesyncd..."
        sudo systemctl restart systemd-timesyncd || {
            log_err "Failed to restart systemd-timesyncd"
            return 1
        }
        sleep 2
        log_ok "systemd-timesyncd restarted successfully"
        echo ""
        timedatectl show
        echo ""
        timedatectl

    else
        log_err "No active NTP service found (chronyd / systemd-timesyncd)"
        return 1
    fi
}
alias ntp-sync='ntp_sync'

# Show current time sync status
alias ntp-status='timedatectl status && timedatectl timesync-status'
# Fix NTP sync and verify result
alias ntp-fix='sudo timedatectl set-ntp true && sudo systemctl restart systemd-timesyncd && sleep 3 && timedatectl status'


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
        log_ok "Timezone set to: $1"
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
            log_err "No timezone found for: $1"
            return 1
        fi

        local -a match_arr
        local sel
        mapfile -t match_arr <<< "$matches"
        radioselect sel "Matching timezones:" -1 "${match_arr[@]}" || { log_info "Cancelled"; return 0; }
        _tz_apply "${match_arr[$sel]}"
        return 0
    fi

    # ── No argument: show current + common zones menu ──────────────────────
    log_step "Current timezone:"
    timedatectl | grep -E "Local time|Time zone"
    echo ""
    local sel
    radioselect sel "Common timezones:" -1 "${COMMON_TZ[@]}" "Enter manually" || { log_info "Cancelled"; return 0; }

    # The extra last option, right after COMMON_TZ
    if (( sel == ${#COMMON_TZ[@]} )); then
        printf "Timezone (e.g. Asia/Taipei): "
        read -r manual
        [[ -z "$manual" ]] && log_info "Cancelled" && return 0
        if timedatectl list-timezones 2>/dev/null | grep -qx "$manual"; then
            _tz_apply "$manual"
        else
            log_err "Invalid timezone: $manual"
            return 1
        fi
    else
        _tz_apply "${COMMON_TZ[$sel]}"
    fi
}
alias tz='tz'

# @name reload_shell
# @description Reload the current shell by sourcing the system-wide bashrc.
#              Auto-detects /etc/bashrc (Rocky/RHEL) or /etc/bash.bashrc (Ubuntu/Debian).
# @example reload_shell
# @example rl
reload_shell() {
    if [[ -f /etc/bashrc ]]; then
        # shellcheck disable=SC1091
        source /etc/bashrc
        log_ok "Reloaded /etc/bashrc"
    elif [[ -f /etc/bash.bashrc ]]; then
        # shellcheck disable=SC1091
        source /etc/bash.bashrc
        log_ok "Reloaded /etc/bash.bashrc"
    else
        log_warn "No system bashrc found — try: source ~/.bashrc"
    fi
}
alias reload-shell='reload_shell'
alias rs='reload_shell'

# @name get_ip
# @description Get primary IPv4 address for prompt display.
#              Uses 'hostname -I' and awk to extract first IP.
#              Silent if no IP is found.
# @example get_ip
get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}
alias get-ip='get_ip'

# @name find_path
# @description Find files or directories by name under a given path (mimics `fd` tool).
#              Automatically splits a full path into pattern and search directory.
#              $1 may hold several whitespace-separated patterns (spaces, tabs or
#              newlines); they are OR'd together in a single find pass. Quote it,
#              or the shell expands the globs before find ever sees them.
# @param $1 string One or more whitespace-separated patterns, or a full path
#                  (e.g. "*.log", "fileA* fileB*", "~/.claude/.claude.json")
# @param $2 string Optional path to search in, default is current directory
# @param $3 string Optional file type: f (file), d (directory), l (symlink)
# @param $4 int    Optional max depth to search
# @example find_path "myfile.txt"
# @example find_path "myfileA myfileB fileC"
# @example find_path "myfileA* myfileB* fileC*" /var/log
# @example find_path "$(cat hashes.txt)"   # one pattern per line also works
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
        log_warn "Use quotes to prevent glob expansion: fp \"${pattern}-*\""
    fi

    # ── Split into patterns ───────────────────────────────────────────────────
    # read -a splits on IFS without globbing (unlike patterns=($pattern), which
    # would expand `file*` against the cwd). -d '' reads to EOF instead of
    # stopping at the first newline, so a multi-line pattern list works too;
    # it returns 1 at EOF, hence the `|| true`.
    local -a patterns
    read -r -d '' -a patterns <<< "$pattern" || true

    if [[ ${#patterns[@]} -eq 0 ]]; then
        log_err "Usage: find_path \"<pattern> [pattern...]\" [path] [type] [depth]"
        return 1
    fi

    # ── Auto-split full path into pattern + directory (single pattern only) ───
    if [[ ${#patterns[@]} -eq 1 && "${patterns[0]}" == */* ]]; then
        path=$(dirname "${patterns[0]}")
        patterns[0]=$(basename "${patterns[0]}")
    fi

    # ── OR the patterns together: \( -name p1 -o -name p2 ... \) ──────────────
    local -a name_expr=()
    local p
    for p in "${patterns[@]}"; do
        [[ ${#name_expr[@]} -gt 0 ]] && name_expr+=(-o)
        name_expr+=(-name "$p")
    done

    # -maxdepth is an option, so it must precede any test in the expression
    local args=()
    [[ -n "$depth" ]] && args+=(-maxdepth "$depth")
    [[ -n "$type" ]]  && args+=(-type "$type")

    local results
    results=$(find "$path" "${args[@]}" \( "${name_expr[@]}" \))

    if [[ -z "$results" ]]; then
        log_err "No matches found for: ${patterns[*]}"
        return 1
    fi

    log_ok "Found the following matches:"
    echo -e "${STYLE[fg_bright_green]}${results}${STYLE[reset]}"

    # ── Call out patterns that contributed nothing (partial hit) ─────────────
    # Classify the single find pass instead of re-running find per pattern:
    # $p stays unquoted so it is matched as a glob against each basename,
    # the same way find -name does.
    if [[ ${#patterns[@]} -gt 1 ]]; then
        local -a missing=()
        local line hit
        for p in "${patterns[@]}"; do
            hit=""
            while IFS= read -r line; do
                # shellcheck disable=SC2053  # unquoted $p is the point: glob match
                [[ "${line##*/}" == $p ]] && { hit=1; break; }
            done <<< "$results"
            [[ -z "$hit" ]] && missing+=("$p")
        done
        if [[ ${#missing[@]} -gt 0 ]]; then
            log_warn "No matches for: ${missing[*]}"
        fi
    fi
    return 0
}
alias find-path='find_path'
alias fp='find_path'

# =========================
# --- Memory Utilities ---
# =========================

# @name free_mem
# @description Reclaim RAM by flushing dirty pages and dropping kernel caches
#              (pagecache, dentries, inodes). Standard kernel feature, so it
#              works on Rocky Linux 9+ and Ubuntu 20+ without package detection.
#              Prints memory usage before and after, plus how much was reclaimed.
#              Note: cached memory is not wasted — the kernel reuses it on demand.
#              Forcing a drop can briefly slow I/O until caches warm up again.
# @depends sudo, sync, free, awk
# @example free_mem
# @example fm
free_mem() {
    # ── Capture available memory (MB) before the drop ─────────────────────────
    local before
    before=$(free -m | awk '/^Mem:/ {print $7}')

    log_step "Memory before release:"
    free -h

    # ── Flush dirty pages, then drop caches (level 3) ─────────────────────────
    log_warn "Syncing and dropping caches..."
    sync
    if ! echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null; then
        log_err "Failed to drop caches (root privileges required)"
        return 1
    fi

    # ── Capture available memory (MB) after the drop ──────────────────────────
    local after
    after=$(free -m | awk '/^Mem:/ {print $7}')

    echo ""
    log_step "Memory after release:"
    free -h

    # ── Report the difference in available memory ─────────────────────────────
    echo ""
    log_ok "Reclaimed $(( after - before )) MB (available: ${before} MB -> ${after} MB)"
}
alias free-mem='free_mem'
alias fm='free_mem'

# @name _pkg_manager
# @description Internal: echo the system package manager to stdout -- apt if present,
#              else dnf; return 1 (nothing echoed) if neither is found. Shared auto-
#              detection for sys_update / sys_toolkit. Distinct from PKG_DEFAULT_MANAGER,
#              the static default used by pkg_* when -m is omitted.
#              (The pkg_* family and sys_toolkit that also consume this live in
#              .bash_pkg, sourced after this file.)
# @returns 0 with manager name on stdout; 1 if no supported manager
_pkg_manager() {
    if command -v apt &>/dev/null; then
        echo apt
    elif command -v dnf &>/dev/null; then
        echo dnf
    else
        return 1
    fi
}

# @name sys_update
# @description Update and upgrade system packages (supports apt and dnf).
# @depends _pkg_manager
# @example sys_update
sys_update() {
    local mgr
    mgr=$(_pkg_manager) || { log_err "No supported package manager found (apt/dnf)"; return 1; }
    case "$mgr" in
        apt)
            log_info "Updating via apt..."
            sudo apt update -y && sudo apt upgrade -y
            ;;
        dnf)
            log_info "Updating via dnf..."
            sudo dnf update -y
            ;;
    esac
}
alias sys-update='sys_update'
alias sup='sys_update'

# @name sys_maintain
# @description Update system packages and clean up disk.
# @depends sys_update, clean_up_disk (.bash_disk)
# @example sys_maintain
sys_maintain() {
    sys_update && clean_up_disk
}
alias sys-maint='sys_maintain'

# =========================
# --- UI Helpers ---
# =========================

# @name multiselect
# @description Interactive multi-select menu (pure bash): Up/Down or j/k to move,
#              SPACE to toggle, a to toggle all, ENTER to confirm, q to cancel. Writes
#              the SELECTED INDICES (space-separated, in menu order) into the caller's
#              named variable, so labels may safely contain spaces. Uses the shared
#              STYLE map (from .bash_env) for the reverse-video cursor and green check.
#              Shared engine, consumed across modules -- e.g. .bash_pkg's sys_toolkit -m
#              builds status labels, .bash_git's git_restore_deleted lists deleted files;
#              both apply actions by the returned indices.
#              Note the menu is rendered on one cleared screen with no paging, so
#              callers should keep the option list short enough to fit.
#              The key legend is printed by the engine -- callers must NOT repeat
#              the keybindings in their title.
# @param $1     string  Name of the caller variable to receive selected indices
# @param $2     string  Title shown above the menu (may be empty "")
# @param $3..   string  Option labels to display (plain text recommended)
# @returns 0 on confirm (indices in the out-var); 1 on cancel or end of input
#          (out-var emptied)
# @example multiselect PICKS "Pick tools:" jq htop lnav
# @example for i in $PICKS; do echo "chose index $i"; done
multiselect() {
    local result_var="$1" title="$2"; shift 2
    local -a labels=("$@")
    local -A picked=()
    local cursor=0
    local i key rest box

    while true; do
        clear
        [[ -n "$title" ]] && log_step "$title"
        # Keys are the engine's contract, so the engine documents them -- otherwise
        # every caller has to remember to spell them out in its own title.
        echo -e "${STYLE[dim]}  ↑/↓ or j/k move · SPACE toggle · a all · ENTER confirm · q cancel${STYLE[reset]}"
        echo ""
        for i in "${!labels[@]}"; do
            if [[ "$i" -eq "$cursor" ]]; then
                # Cursor row: plain box + reverse-video whole line (no inner resets).
                box="[ ]"; [[ -n "${picked[$i]:-}" ]] && box="[✔]"
                echo -e "  ${STYLE[reverse]}${box} ${labels[$i]}${STYLE[reset]}"
            else
                box="[ ]"; [[ -n "${picked[$i]:-}" ]] && box="[${STYLE[fg_green]}✔${STYLE[reset]}]"
                echo -e "  ${box} ${labels[$i]}"
            fi
        done

        # End of input cancels, else it would read as ENTER and confirm
        IFS= read -rsn1 key || { clear; printf -v "$result_var" '%s' ""; return 1; }
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 -t 1 rest   # -t guards against a lone ESC hanging the read
            # O* is application cursor mode, which some SSH clients (e.g. PuTTY) send
            case "$rest" in
                '[A' | OA) (( cursor > 0 )) && (( cursor-- )) ;;
                '[B' | OB) (( cursor < ${#labels[@]} - 1 )) && (( cursor++ )) ;;
            esac
            continue
        fi
        case "$key" in
            k | K) (( cursor > 0 )) && (( cursor-- )) ;;
            j | J) (( cursor < ${#labels[@]} - 1 )) && (( cursor++ )) ;;
            ' ')
                if [[ -n "${picked[$cursor]:-}" ]]; then unset "picked[$cursor]"; else picked[$cursor]=1; fi
                ;;
            a | A)
                if [[ ${#picked[@]} -eq ${#labels[@]} ]]; then
                    picked=()
                else
                    for i in "${!labels[@]}"; do picked[$i]=1; done
                fi
                ;;
            q | Q) clear; printf -v "$result_var" '%s' ""; return 1 ;;
            '') break ;;   # ENTER
        esac
    done
    clear

    # Collect selected indices in menu order.
    local -a sel=()
    for i in "${!labels[@]}"; do
        [[ -n "${picked[$i]:-}" ]] && sel+=("$i")
    done
    printf -v "$result_var" '%s' "${sel[*]}"
    return 0
}
alias multi-select='multiselect'

# @name radioselect
# @description Interactive single-select menu (pure bash): Up/Down or j/k to move,
#              type a number to jump to it, ENTER to pick, q to cancel. Writes the
#              SELECTED INDEX (0-based) into the caller's named variable -- the same
#              contract as multiselect, so labels may safely contain spaces.
#              Built to replace hand-rolled numbered menus:
#                - Items are numbered and typed digits accumulate, so the old habit of
#                  typing "12" then ENTER still lands on item 12.
#                - Drawn on stderr and never clears the screen, redrawing in place: it
#                  works inside $(...) (a wrapper can echo the pick to stdout, as
#                  _pkg_search_select does) and leaves the caller's output above it
#                  in view.
#                - Lists taller than the terminal scroll, with a "-- n/total --" line.
#                - End of input cancels instead of picking the highlighted default, so
#                  a script without a terminal can never choose by accident.
#              Labels are cut to the terminal width, because the redraw moves the cursor
#              up one row per line and a wrapped label would shift every later redraw
#              (CJK chars count 1 column but render 2, as in log_banner).
#              Shared engine, consumed across modules -- .bash_disk's disk_grow, tz,
#              .bash_git's branch pickers, .bash_pkg's _pkg_search_select.
#              The key legend is printed by the engine -- callers must NOT repeat the
#              keybindings in their title.
# @param $1     string  Name of the caller variable to receive the selected index; must
#                       not be one of the engine's own locals (cursor, key, labels, ...)
# @param $2     string  Title shown above the menu (may be empty "" when the caller
#                       prints its own header)
# @param $3     int     Index highlighted at start, i.e. what a bare ENTER picks. -1
#                       highlights nothing, so ENTER does nothing until a choice is
#                       made -- use it for menus that act at once, where the old
#                       numbered menus also ignored a bare ENTER
# @param $4..   string  Option labels to display (plain text)
# @returns 0 on pick (index in the out-var); 1 on cancel or end of input (out-var emptied)
# @example radioselect PICK "Grow which mount point?" 0 "/" "/home"
# @example radioselect PICK "Switch to which branch?" -1 "${branches[@]}"
# @example echo "chose index ${PICK}"
radioselect() {
    local result_var="$1" title="$2" cursor="$3"; shift 3
    local -a labels=("$@")
    local n=${#labels[@]} cols lines num_w width rows height top=0 i key rest digits="" drawn=0
    cols=${COLUMNS:-$(tput cols 2>/dev/null)}
    lines=${LINES:-$(tput lines 2>/dev/null)}
    num_w=${#n}
    width=$(( ${cols:-80} - num_w - 8 ))   # "  (•) " + number + space, 1 so it never wraps
    rows=$(( ${lines:-24} - 5 ))            # room for title, legend and the caller's next prompt
    (( rows < 3 )) && rows=3
    (( rows > n )) && rows=$n
    height=$rows
    (( n > rows )) && (( height++ ))        # the "-- n/total --" line

    [[ -n "$title" ]] && printf '%s%s%s\n' "${STYLE[fg_yellow]}" "$title" "${STYLE[reset]}" >&2
    printf '%s  ↑/↓ or j/k move · type a number to jump · ENTER pick · q cancel%s\n' \
        "${STYLE[dim]}" "${STYLE[reset]}" >&2
    while true; do
        (( cursor >= 0 && cursor < top )) && top=$cursor
        (( cursor >= top + rows )) && top=$(( cursor - rows + 1 ))
        {
            (( drawn )) && printf '\e[%dA' "$height"
            for (( i = top; i < top + rows; i++ )); do
                if (( i == cursor )); then
                    printf '\e[2K  %s(•) %*d %s%s\n' "${STYLE[reverse]}" "$num_w" $(( i + 1 )) "${labels[$i]:0:width}" "${STYLE[reset]}"
                else
                    printf '\e[2K  ( ) %*d %s\n' "$num_w" $(( i + 1 )) "${labels[$i]:0:width}"
                fi
            done
            (( n > rows )) && printf '\e[2K  %s-- %d/%d --%s\n' "${STYLE[dim]}" $(( cursor + 1 )) "$n" "${STYLE[reset]}"
        } >&2
        drawn=1

        IFS= read -rsn1 key || { printf -v "$result_var" '%s' ""; return 1; }
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 -t 1 rest   # -t guards against a lone ESC hanging the read
            # O* is application cursor mode, which some SSH clients (e.g. PuTTY) send
            case "$rest" in
                '[A' | OA) (( cursor > 0 )) && (( cursor-- )) ;;
                '[B' | OB) (( cursor < n - 1 )) && (( cursor++ )) ;;
            esac
            digits=""
            continue
        fi
        case "$key" in
            [0-9])
                # 10# keeps a leading 0 from being read as octal
                digits+=$key
                (( 10#$digits >= 1 && 10#$digits <= n )) || digits=$key
                (( 10#$digits >= 1 && 10#$digits <= n )) && cursor=$(( 10#$digits - 1 ))
                ;;
            k | K) (( cursor > 0 )) && (( cursor-- )); digits="" ;;
            j | J) (( cursor < n - 1 )) && (( cursor++ )); digits="" ;;
            q | Q) printf -v "$result_var" '%s' ""; return 1 ;;
            '') (( cursor >= 0 )) && break ;;   # ENTER; ignored while nothing is highlighted
        esac
    done
    printf -v "$result_var" '%s' "$cursor"
}
alias radio-select='radioselect'

# =========================
# --- Project Commands ---
# =========================

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
        log_err "Project not found: $project"
        return 1
    }

    log_info "Running pnpm $script in $project"
    pnpm "$script"
}

# General alias to run project with parameters
alias run-prj='run_project'

# Aliases for a specific project (replace 'myproject' with your actual project name)
alias run-dev='run_project dev'
alias run-prj-dev='run_project dev'
alias run-prod='run_project start:prod'
alias run-prj-prod='run_project start:prod'

# Stop dev server on a specified port (default: 3001).
#
# Usage:
#   stop-dev [port] [-9]
#
# Arguments:
#   port   (optional) Port number to target. Defaults to 3001.
#   -9     (optional) Force kill (SIGKILL). Defaults to graceful (SIGTERM).
#
# Examples:
#   stop-dev              # port 3001, graceful
#   stop-dev -9           # port 3001, force
#   stop-dev 3002         # port 3002, graceful
#   stop-dev 3002 -9      # port 3002, force
#   stop-dev -9 3002      # order-insensitive
stop_dev() {
    local port_num=3001
    local force=""

    for arg in "$@"; do
        if [[ "$arg" == "-9" ]]; then
            force="-9"
        elif [[ "$arg" =~ ^[0-9]+$ ]]; then
            port_num=$arg
        fi
    done

    local pid=$(sss | grep "${port_num}" | grep -oP "(?<=pid=)[0-9]+")
    if [[ -z "$pid" ]]; then
        log_info "No process found on port ${port_num}"
        return 1
    fi

    if [[ -n "$force" ]]; then
        log_info "Force stopping dev server on port ${port_num} (pid=${pid})"
        kill -9 "$pid"
    else
        log_info "Stopping dev server on port ${port_num} (pid=${pid})"
        kill "$pid"
    fi
}
alias stop-dev='stop_dev'

############################################################
