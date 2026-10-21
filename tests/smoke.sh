#!/usr/bin/env bash
# =============================================================================
# tests/smoke.sh — the runtime library (configs/alias), sourced like its users do
# =============================================================================
# Each check runs in a CLEAN bash (env -i, no rc files) that sources the entry point
# the way one of its three consumers does:
#   - strict mode (set -euo pipefail), as lib/core.sh and the cron scripts do -- a
#     module whose last line returns non-zero kills such a caller silently;
#   - with no terminal, which is what cron and pipes look like: confirm must say no,
#     menus must cancel, nothing may wait for input;
#   - on both distro families (OS_FAMILY preset): the platform globals must agree.
#
# USAGE: bash tests/smoke.sh        (no root needed)
# EXIT:  0 all passed, 1 any failed
# Standalone: it only sources the library under test, never lib/.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRY="$ROOT/configs/alias/.bash_aliases"
pass=0 fail=0

# run <label> <family|-> <script>: the script runs after sourcing the library in a
# clean, strict, terminal-less bash; it passes when it exits 0.
run() {
    local label="$1" family="$2" script="$3" out
    local -a env=(HOME="$HOME" USER="${USER:-$(id -un)}" TERM=dumb
                  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin)
    local -a preset=()
    [[ "$family" != - ]] && read -ra preset <<< "$family"
    env+=("${preset[@]}")
    if out=$(env -i "${env[@]}" bash --noprofile --norc -c "set -euo pipefail; source '$ENTRY'; $script" </dev/null 2>&1); then
        printf '  ok    %s\n' "$label"; pass=$((pass + 1))
    else
        printf '  FAIL  %s\n%s\n' "$label" "$(sed 's/^/        /' <<< "$out" | tail -8)"; fail=$((fail + 1))
    fi
}

echo "== loading =="
run "sources under set -euo pipefail" - 'true'
run "sources twice (re-source from rs)" - 'source "'"$ENTRY"'"'
run "every module present" - '(( ${#ALIAS_MODULES[@]} >= 10 ))'

echo ""
echo "== platform globals =="
run "this host is detected and supported" - '[[ $OS_FAMILY == debian || $OS_FAMILY == rhel ]] && os_supported && [[ -n $PKG_MGR ]]'
run "debian family: apt, /etc/bash.bashrc" "OS_FAMILY=debian OS_ID=ubuntu OS_VERSION=20.04" \
    '[[ $PKG_MGR == apt && $SYS_BASHRC == /etc/bash.bashrc ]] && os_supported'
run "rhel family: dnf, /etc/bashrc" "OS_FAMILY=rhel OS_ID=rocky OS_VERSION=9.4" \
    '[[ $PKG_MGR == dnf && $SYS_BASHRC == /etc/bashrc && $OS_MAJOR == 9 ]] && os_supported'
run "RHEL 8 / Ubuntu 18.04 are refused" - \
    '! OS_FAMILY=rhel OS_ID=rhel OS_MAJOR=8 os_supported && ! OS_FAMILY=debian OS_ID=ubuntu OS_MAJOR=18 os_supported'
run "SUDO is empty only for root" - '[[ $EUID -eq 0 && -z $SUDO ]] || [[ $EUID -ne 0 && $SUDO == sudo ]]'
run "git is in the toolkit" - '[[ " ${SYS_TOOLKIT[*]} " == *" git "* ]]'

echo ""
echo "== package names =="
run "dnf: build-essential -> gcc gcc-c++ make" - '[[ "$(_pkg_name dnf build-essential)" == "gcc gcc-c++ make" ]]'
run "apt: ShellCheck -> shellcheck" - '[[ "$(_pkg_name apt ShellCheck)" == shellcheck ]]'
run "unmapped names pass through" - '[[ "$(_pkg_name apt jq)" == jq ]]'
# A probe package nothing has installed and a map entry of our own: the expected line is
# the same on any host (a real RHEL host already has git, and rightly leaves it out).
run "rhel dry run: EPEL first, then mapped names" "OS_FAMILY=rhel OS_ID=rocky OS_VERSION=9.4" \
    'PKG_NAME_MAP[dnf:dotfiles-probe]="probe-a probe-b"
     out=$(pkg_enable_epel -n; pkg_install -n dotfiles-probe)
     grep -qE "epel-release|EPEL already enabled" <<< "$out" && grep -q "dnf install -y probe-a probe-b" <<< "$out"'
run "the toolkit dry run succeeds" - 'sys_toolkit -n >/dev/null'
run "RHEL itself enables CRB through subscription-manager" "OS_FAMILY=rhel OS_ID=rhel OS_VERSION=9.4" \
    'pkg_enable_epel -n | grep -q "subscription-manager repos --enable codeready-builder-for-rhel-9"'

echo ""
echo "== no terminal: nothing waits, nothing destructive =="
run "confirm says no" - '! confirm "Delete everything?"'
run "UI_ASSUME_YES=1 makes confirm say yes" - 'UI_ASSUME_YES=1 confirm "Proceed?"'
run "ask fails instead of waiting" - '! ask v "Name"'
run "radioselect cancels at end of input" - '! radioselect v "Pick" 0 a b c && [[ -z $v ]]'
run "multiselect cancels at end of input" - '! multiselect v "Pick" a b c 2>/dev/null && [[ -z $v ]]'
run "a git menu command fails with usage" - 'cd "'"$ROOT"'"; out=$(git_switch_and_pull 2>&1) && exit 1; grep -q usage <<< "$out"'
run "gds without indices fails with usage" - 'cd "'"$ROOT"'"; ! git_drop_stashes >/dev/null 2>&1 || ! git stash list | grep -q .'

echo ""
echo "== commands =="
run "every public command has its alias" - 'for a in pi pe prm toolkit sup os-upgrade cud chc dut ds dg gfm gpcb gswp gcr gds gcmb grd gfl amend rs fp fm ngs nvm-i nvm-up; do alias "$a" >/dev/null; done'
run "-h prints usage and succeeds" - 'for f in sys_update os_upgrade clean_up_disk clean_home_caches sys_toolkit pkg_install run_project stop_dev tz git_clean_merged git_drop_stashes; do $f -h | grep -q usage; done'
run "unknown options are refused" - '! sys_update --bogus 2>/dev/null && ! clean_up_disk --bogus 2>/dev/null && ! os_upgrade --bogus 2>/dev/null'
run "sys_update -n prints, runs nothing" - 'sys_update -n | grep -q "upgrade"'
run "clean_home_caches -n deletes nothing" - 'clean_home_caches -n >/dev/null'
run "log helpers write the DOTFILES_LOG_FILE sink" - 'f=$(mktemp); DOTFILES_LOG_FILE=$f log_ok probe >/dev/null; grep -q "\[OK\] probe" "$f"; rm -f "$f"'
run "prompt hook is added once and keeps PROMPT_COMMAND" - 'PROMPT_COMMAND=title; prompt_enable; prompt_enable; [[ $PROMPT_COMMAND == "build_ps1;title" ]]'
run "build_ps1 sets a prompt" - 'build_ps1; [[ $PS1 == *"\\W"* ]]'
# Minimal RHEL-family images have no `hostname`; neither may break the prompt
run "the prompt survives without ip and hostname" - 'ip() { return 1; }; hostname() { return 127; }; build_ps1; [[ -z "$(get_ip)" ]]'

echo ""
echo "== release upgrades (dry runs only) =="
UBUNTU="OS_FAMILY=debian OS_ID=ubuntu OS_VERSION=22.04"
ROCKY="OS_FAMILY=rhel OS_ID=rocky OS_VERSION=9.6"
run "with no action and no terminal it fails with usage" - \
    'out=$(os_upgrade 2>&1) && exit 1; grep -q usage <<< "$out"'
run "ubuntu: run = full update (do-release-upgrade refuses kept-back updates), backup, upgrade" "$UBUNTU" \
    'out=$(os_upgrade -n run 2>&1)
     grep -q "apt-get full-upgrade" <<< "$out" && grep -q "etc.tar.gz" <<< "$out" &&
     grep -q "apt-mark showmanual" <<< "$out" && grep -q "would run: .*do-release-upgrade$" <<< "$out"'
run "ubuntu: -y makes the upgrade non-interactive" "$UBUNTU" \
    'os_upgrade -n -y run 2>&1 | grep -q "do-release-upgrade -f DistUpgradeViewNonInteractive"'
run "rocky: run refuses before touching anything" "$ROCKY" \
    'out=$(os_upgrade -n run 2>&1) && exit 1
     grep -q "No in-place upgrade for rocky" <<< "$out" && ! grep -q "would run" <<< "$out"'
run "rocky: backup saves what a reinstall needs" "$ROCKY" \
    'out=$(os_upgrade -n backup); grep -q "repoquery --userinstalled" <<< "$out" && grep -q "etc.tar.gz" <<< "$out"'
run "ubuntu: cleanup ends in clean_up_disk" "$UBUNTU" 'out=$(os_upgrade -n cleanup 2>&1); grep -q "apt-get autoremove" <<< "$out"'
# apt stubs: oldlib/oldmeta are the old release's (logged obsolete), mydeb is a local
# .deb (obsolete, not logged), user-dev still depends on oldlib. Purging the old
# release must never take user-dev or mydeb along.
APT_STUBS='log=$(mktemp); echo "x DEBUG Obsolete: oldlib oldmeta" > "$log"; OS_UPGRADE_UBUNTU_LOG=$log
     apt() { printf "%s\n" Listing... "oldlib/now 1 arm64 [installed,local]" "oldmeta/now 1 arm64 [installed,local]" "mydeb/now 1 arm64 [installed,local]"; }'
run "ubuntu: cleanup purges the old release, keeping what depends on it via its replacement" "$UBUNTU" \
    "$APT_STUBS"'
     apt-get() { case " $* " in
         *" user-dev+ "*) printf "%s\n" "Purg oldlib [1]" "Purg oldmeta [1]" "Inst newlib (2 x)" ;;
         *" -s "*)        printf "%s\n" "Purg oldlib [1]" "Purg oldmeta [1]" "Purg user-dev [1]" ;;
     esac; }
     out=$(os_upgrade -n cleanup 2>&1)
     grep -q "would run: .*apt-get purge -y oldlib oldmeta user-dev+$" <<< "$out" &&
     grep -q "install  newlib" <<< "$out" && ! grep -q "remove   user-dev" <<< "$out" &&
     grep -A1 "not from the old release" <<< "$out" | grep -q mydeb'
run "ubuntu: cleanup purges nothing when apt cannot keep the dependents" "$UBUNTU" \
    "$APT_STUBS"'
     apt-get() { printf "%s\n" "Purg oldlib [1]" "Purg oldmeta [1]" "Purg user-dev [1]"; }
     out=$(os_upgrade -n cleanup 2>&1)
     ! grep -q "apt-get purge -y oldlib" <<< "$out" && grep -q "apt finds no way to keep" <<< "$out"'
run "rocky: cleanup ends in clean_up_disk" "$ROCKY" 'out=$(os_upgrade -n cleanup 2>&1); grep -q "dnf autoremove" <<< "$out"'
run "a distro is added by its hooks alone" "OS_FAMILY=debian OS_ID=testos OS_VERSION=1" \
    '_os_upgrade_testos_run() { echo HOOKED; }
     os_upgrade -n run 2>&1 | grep -q HOOKED && ! OS_ID=debian os_upgrade -n run >/dev/null 2>&1'

echo ""
echo "Assertions: ${pass} passed, ${fail} failed"
(( fail == 0 )) || { echo "SMOKE: FAIL"; exit 1; }
echo "SMOKE: PASS"
