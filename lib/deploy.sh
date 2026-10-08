#!/usr/bin/env bash
# @file lib/deploy.sh
# @brief File primitives for deploy modules: install, mirror a directory, manage a
#        block inside a shared file, render a template, validate before installing.
# @description
#   Sourced by lib/core.sh. Every file a module writes goes through these, so every
#   write gets the same guarantees:
#     - DF_ROOT sandbox: paths are written under DF_ROOT (tests point it at a temp dir);
#     - DF_DRY_RUN: the change is printed, nothing is written;
#     - idempotent: an identical file with the right mode is reported "unchanged";
#     - a replaced or removed file is copied to DF_BACKUP_DIR first (one dir per run,
#       mirroring the absolute path);
#     - validators run on the SOURCE, before anything lands -- a broken sudoers or
#       logrotate file never reaches the system;
#     - files written as root end up root:root unless a module says otherwise.

# @const DF_RUN_ID     One id per install run (exported), naming its backups.
DF_RUN_ID="${DF_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
export DF_RUN_ID
# @const DF_BACKUP_DIR Where replaced files are kept: /var/backups/dotfiles/<run> for a
#                      root run, inside the sandbox for DF_ROOT, else the user's state dir.
if [[ -n "$DF_ROOT" ]]; then
    DF_BACKUP_DIR="${DF_ROOT}/var/backups/dotfiles/${DF_RUN_ID}"
elif (( EUID == 0 )); then
    DF_BACKUP_DIR="/var/backups/dotfiles/${DF_RUN_ID}"
else
    DF_BACKUP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/${DF_RUN_ID}"
fi

# @name df_path
# @description The real path for a system path: DF_ROOT prefixed.
# @example target=$(df_path /etc/cron.d/dotfiles-maint)
df_path() { printf '%s%s' "$DF_ROOT" "$1"; }

# @name df_backup
# @description Copy an existing real path (already DF_ROOT-prefixed) into DF_BACKUP_DIR.
df_backup() {
    local real="$1"
    [[ -e "$real" || -L "$real" ]] || return 0
    local dest="${DF_BACKUP_DIR}${real#"$DF_ROOT"}"
    mkdir -p "$(dirname "$dest")"
    cp -a "$real" "$dest"
}

# @name _df_chown
# @description Internal: chown a real path when running as root (owner default root:root).
_df_chown() {
    (( EUID == 0 )) || return 0
    chown "${2:-root:root}" "$1"
}

# @name df_install
# @description Install one file at a system path with a mode (and owner, when root).
# @param -m  string  Mode (default 0644)
# @param -o  string  Owner user:group (default root:root; only applied as root)
# @param -v  string  Validator function, run on SRC first (e.g. df_check_bash)
# @param $1  string  Source file
# @param $2  string  Destination system path
# @example df_install -m 0750 -v df_check_bash configs/sbin/sys-maint.sh /usr/local/sbin/sys-maint.sh
df_install() {
    local mode=0644 owner="" validator=""
    while [[ "${1:-}" == -* ]]; do
        case "$1" in
            -m) mode="$2" ;;
            -o) owner="$2" ;;
            -v) validator="$2" ;;
            *)  die "df_install: unknown option $1" ;;
        esac
        shift 2
    done
    local src="$1" dst="$2"
    [[ -f "$src" ]] || die "df_install: no such file: ${src}"
    if [[ -n "$validator" ]]; then
        "$validator" "$src" || die "${src} failed ${validator} -- not installed"
    fi

    local target
    target=$(df_path "$dst")
    if [[ -f "$target" ]] && cmp -s "$src" "$target" && [[ "$(stat -c %a "$target")" == "${mode#0}" ]]; then
        log_ok "unchanged  ${dst}"
        return 0
    fi
    if (( DF_DRY_RUN )); then
        local shown="${src#"$DOTFILES_ROOT"/}"
        [[ "$shown" == /* ]] && shown="(generated)"
        log_info "[dry-run] install -m ${mode} ${shown} -> ${dst}"
        return 0
    fi
    df_backup "$target"
    install -D -m "$mode" "$src" "$target"
    _df_chown "$target" "$owner"
    log_ok "installed  ${dst} (${mode})"
}

# @name df_install_dir
# @description Install every file under SRCDIR (recursively) into DSTDIR, keeping the
#              relative layout. Templates and notes stay behind: *.example, *.example.*
#              and README.md are never installed. Files the source no longer has can
#              be removed (backed up first), two ways:
#                -p GLOB  for a directory dotfiles owns outright: anything matching the
#                         glob that is not in the source goes -- except -k matches,
#                         which belong to the host;
#                -M       for a directory shared with others (~/.claude/skills holds
#                         skills from plugins and syncs too): DSTDIR/.dotfiles-manifest
#                         records what dotfiles installed, and only those files are
#                         ever removed. A first run, with no manifest yet, removes nothing.
# @param -m  string  Mode for every file (default 0644)
# @param -o  string  Owner (as df_install)
# @param -v  string  Validator for every file
# @param -p  string  Prune glob, matched against basenames (e.g. '.bash_*')
# @param -k  string  Keep glob, never pruned (e.g. '.bash_local')
# @param -M  flag    Manifest mode (no value)
# @param $1  string  Source directory
# @param $2  string  Destination system directory
# @example df_install_dir -p '.bash_*' -k '.bash_local' configs/alias "$ALIAS_DIR"
# @example df_install_dir -M configs/claude/skills ~/.claude/skills
df_install_dir() {
    local mode=0644 owner="" validator="" prune="" keep="" manifest=0
    while [[ "${1:-}" == -* ]]; do
        case "$1" in
            -m) mode="$2" ;;
            -o) owner="$2" ;;
            -v) validator="$2" ;;
            -p) prune="$2" ;;
            -k) keep="$2" ;;
            -M) manifest=1; shift; continue ;;
            *)  die "df_install_dir: unknown option $1" ;;
        esac
        shift 2
    done
    local src_dir="${1%/}" dst_dir="${2%/}"
    [[ -d "$src_dir" ]] || die "df_install_dir: no such directory: ${src_dir}"

    local -a args=(-m "$mode")
    [[ -n "$owner" ]] && args+=(-o "$owner")
    [[ -n "$validator" ]] && args+=(-v "$validator")

    local -A wanted=()
    local f rel
    while IFS= read -r -d '' f; do
        rel="${f#"$src_dir"/}"
        case "${rel##*/}" in
            *.example | *.example.* | README.md) continue ;;
        esac
        wanted[$rel]=1
        df_install "${args[@]}" "$f" "${dst_dir}/${rel}"
    done < <(find "$src_dir" -type f -print0 | sort -z)

    (( manifest )) && _df_manifest_sync "$dst_dir" "$owner" "${!wanted[@]}"
    [[ -n "$prune" ]] || return 0
    local target_dir name
    target_dir=$(df_path "$dst_dir")
    [[ -d "$target_dir" ]] || return 0
    while IFS= read -r -d '' f; do
        rel="${f#"$target_dir"/}"
        name="${rel##*/}"
        [[ -n "${wanted[$rel]:-}" ]] && continue
        # shellcheck disable=SC2053  # glob match is the point
        [[ "$name" == $prune ]] || continue
        # shellcheck disable=SC2053
        [[ -n "$keep" && "$name" == $keep ]] && continue
        if (( DF_DRY_RUN )); then
            log_info "[dry-run] remove ${dst_dir}/${rel} (no longer in ${src_dir#"$DOTFILES_ROOT"/})"
            continue
        fi
        df_backup "$f"
        rm -f "$f"
        log_warn "removed    ${dst_dir}/${rel} (no longer in ${src_dir#"$DOTFILES_ROOT"/})"
    done < <(find "$target_dir" -type f -print0)
}

# @name _df_manifest_sync
# @description Internal (df_install_dir -M): remove what the previous manifest of
#              DSTDIR lists but the current install does not, then record the current
#              set. Only paths dotfiles itself wrote are ever candidates.
# @param $1    string  Destination system directory
# @param $2    string  Owner for the manifest file (may be empty)
# @param $3..  string  Relative paths installed this run
_df_manifest_sync() {
    local dst_dir="$1" owner="$2"; shift 2
    local -A now=()
    local rel
    for rel in "$@"; do now[$rel]=1; done
    local mf real
    mf=$(df_path "$dst_dir/.dotfiles-manifest")
    if [[ -f "$mf" ]]; then
        while IFS= read -r rel; do
            [[ -z "$rel" || -n "${now[$rel]:-}" ]] && continue
            real=$(df_path "$dst_dir/$rel")
            [[ -e "$real" || -L "$real" ]] || continue
            if (( DF_DRY_RUN )); then
                log_info "[dry-run] remove ${dst_dir}/${rel} (dropped from the repo)"
                continue
            fi
            df_backup "$real"
            rm -f "$real"
            log_warn "removed    ${dst_dir}/${rel} (dropped from the repo)"
        done < "$mf"
    fi
    (( DF_DRY_RUN )) && return 0
    local tmp
    tmp=$(mktemp)
    printf '%s\n' "$@" | sort > "$tmp"
    if ! cmp -s "$tmp" "$mf" 2>/dev/null; then
        install -D -m 0644 "$tmp" "$mf"
        _df_chown "$mf" "$owner"
    fi
    rm -f "$tmp"
}

# @name df_block_check
# @description Die if FILE holds the begin marker of block NAME without its end marker
#              -- a hand edit gone wrong, where replacing "the block" would eat the rest
#              of the file. df_block runs it; call it yourself before any OTHER edit to
#              the same file, so a refused deploy leaves the file untouched.
# @example df_block_check "$SYS_BASHRC" hook
df_block_check() {
    local target begin="# >>> dotfiles:${2} >>>" end="# <<< dotfiles:${2} <<<"
    target=$(df_path "$1")
    [[ -f "$target" ]] || return 0
    if grep -qxF -- "$begin" "$target" && ! grep -qxF -- "$end" "$target"; then
        die "${1} has '${begin}' but no '${end}' -- repair it by hand"
    fi
}

# @name df_block
# @description Own one block inside a file other things also write -- the system
#              bashrc, say -- between "# >>> dotfiles:NAME >>>" and
#              "# <<< dotfiles:NAME <<<". The block is replaced in place on every run
#              and the rest of the file is left exactly as it was. A begin marker with
#              no end marker means a hand edit went wrong: refuse rather than guess
#              where the block stops.
# @param $1 string  System path of the file
# @param $2 string  Block name
# @param $3 string  Block content (without markers); empty removes the block
# @example df_block "$SYS_BASHRC" hook "$hook"
df_block() {
    local file="$1" name="$2" content="$3"
    local target begin="# >>> dotfiles:${name} >>>" end="# <<< dotfiles:${name} <<<"
    target=$(df_path "$file")
    df_block_check "$file" "$name"
    local new
    new=$(mktemp)
    if [[ -f "$target" ]]; then
        # Drop the old block, then trailing blank lines, so re-runs never grow the file
        awk -v b="$begin" -v e="$end" '
            $0 == b { skip = 1; next }
            skip && $0 == e { skip = 0; next }
            skip { next }
            /^[[:space:]]*$/ { blank = blank $0 "\n"; next }
            { printf "%s%s\n", blank, $0; blank = "" }
        ' "$target" > "$new"
    fi
    if [[ -n "$content" ]]; then
        [[ -s "$new" ]] && echo "" >> "$new"
        printf '%s\n%s\n%s\n' "$begin" "$content" "$end" >> "$new"
    fi

    if [[ -f "$target" ]] && cmp -s "$new" "$target"; then
        rm -f "$new"
        log_ok "unchanged  ${file} (dotfiles:${name})"
        return 0
    fi
    if (( DF_DRY_RUN )); then
        log_info "[dry-run] update block dotfiles:${name} in ${file}"
        rm -f "$new"
        return 0
    fi
    df_backup "$target"
    mkdir -p "$(dirname "$target")"
    if [[ -f "$target" ]]; then
        cat "$new" > "$target"     # in place: the file keeps its owner and mode
    else
        install -m 0644 "$new" "$target"
    fi
    rm -f "$new"
    log_ok "updated    ${file} (dotfiles:${name})"
}

# @name df_render
# @description Print a template with every __NAME__ replaced by the value of $NAME,
#              for the names given; die if any __NAME__ is left unreplaced.
# @param $1  string  Template file
# @param $2.. string Variable names
# @example df_render configs/sudoers.d/dotfiles.tmpl DEPLOY_USER > "$tmp"
df_render() {
    local src="$1"; shift
    local -a expr=()
    local name val
    for name in "$@"; do
        val="${!name}"
        val="${val//\\/\\\\}"; val="${val//|/\\|}"; val="${val//&/\\&}"
        expr+=(-e "s|__${name}__|${val}|g")
    done
    local out
    out=$(sed "${expr[@]}" "$src")
    if grep -qE '__[A-Z][A-Z0-9_]*__' <<< "$out"; then
        die "${src}: unreplaced placeholder(s): $(grep -oE '__[A-Z][A-Z0-9_]*__' <<< "$out" | sort -u | tr '\n' ' ')"
    fi
    printf '%s\n' "$out"
}

# @name df_render_install
# @description df_render into a temp file, then df_install it (same options).
# @example df_render_install -m 0440 -v df_check_sudoers TEMPLATE DST DEPLOY_USER
df_render_install() {
    local -a opts=()
    while [[ "${1:-}" == -* ]]; do opts+=("$1" "$2"); shift 2; done
    local src="$1" dst="$2"; shift 2
    local tmp rc=0
    tmp=$(mktemp)
    df_render "$src" "$@" > "$tmp"
    df_install "${opts[@]}" "$tmp" "$dst" || rc=$?
    rm -f "$tmp"
    return "$rc"
}

# @name df_write
# @description Install generated content (from stdin) at a system path -- for configs
#              built from settings rather than kept as files. Same options as df_install.
# @example printf '[Resolve]\nDNS=%s\n' "$DNS" | df_write /etc/systemd/resolved.conf.d/dotfiles.conf
df_write() {
    local -a opts=()
    while [[ "${1:-}" == -* ]]; do opts+=("$1" "$2"); shift 2; done
    local tmp rc=0
    tmp=$(mktemp)
    cat > "$tmp"
    df_install "${opts[@]}" "$tmp" "$1" || rc=$?
    rm -f "$tmp"
    return "$rc"
}

# @name df_mkdir
# @description Create a system directory with a mode (root:root when root) -- only if
#              it is missing. An existing directory is left exactly as it is: it may be
#              the distro's (RHEL's /etc/pki/tls/private is 0755), and re-moding a
#              system directory is not a deploy step's call.
# @example df_mkdir -m 0755 "$DOTFILES_LOG_DIR"
df_mkdir() {
    local mode=0755
    [[ "${1:-}" == -m ]] && { mode="$2"; shift 2; }
    local target
    target=$(df_path "$1")
    [[ -d "$target" ]] && return 0
    (( DF_DRY_RUN )) && { log_info "[dry-run] mkdir -m ${mode} $1"; return 0; }
    install -d -m "$mode" "$target"
    _df_chown "$target"
    log_ok "directory  $1 (${mode})"
}

# ##############################################################################
# @section Validators -- run on the source, before it is installed
# ##############################################################################

# @name df_check_bash
# @description Bash syntax check.
df_check_bash() { bash -n "$1"; }

# @name df_check_logrotate
# @description logrotate's own parser, in debug mode (rotates nothing), with a
#              throwaway state file. Skipped with a warning where logrotate is absent.
df_check_logrotate() {
    command -v logrotate &>/dev/null || { log_warn "logrotate not installed -- ${1##*/} not checked"; return 0; }
    local state out rc=0
    state=$(mktemp)
    out=$(logrotate -d -s "$state" "$1" 2>&1) || rc=$?
    rm -f "$state"
    if (( rc )) || grep -qi '^error:' <<< "$out"; then
        printf '%s\n' "$out" | grep -i 'error' >&2
        return 1
    fi
}

# @name df_check_cron
# @description A cron.d file cron will actually read: no dot in the name (Debian's
#              cron skips such files silently), a final newline (the last line is
#              dropped without one), and every job line naming a user.
df_check_cron() {
    local f="$1" name
    name=$(basename "$f")
    [[ "$name" != *.* ]] || { log_err "${name}: cron ignores cron.d files with a dot in the name"; return 1; }
    [[ -z "$(tail -c1 "$f")" ]] || { log_err "${name}: no final newline -- cron drops the last line"; return 1; }
    awk '
        /^[[:space:]]*(#|$)/ { next }
        /^[A-Za-z_][A-Za-z0-9_]*=/ { next }
        /^@/ { if (NF < 3) { bad = 1; print "line " NR ": @schedule user command" > "/dev/stderr" } next }
        NF < 7 { bad = 1; print "line " NR ": min hour dom mon dow user command" > "/dev/stderr" }
        END { exit bad }
    ' "$f"
}

# @name df_check_sudoers
# @description visudo's parser on the file alone. A broken sudoers drop-in can lock
#              everyone out of sudo, so there is no skipping this one.
df_check_sudoers() {
    command -v visudo &>/dev/null || { log_err "visudo not found -- refusing to install a sudoers file unchecked"; return 1; }
    visudo -cqf "$1"
}
