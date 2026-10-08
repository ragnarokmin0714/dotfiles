#!/usr/bin/env bash
# =============================================================================
# tests/deploy.sh — the deploy framework, end to end, in --root sandboxes
# =============================================================================
# Runs the real install.sh and modules against temporary roots seeded with what a host
# already has (a distro bashrc carrying the old alias loader, an /etc/gitconfig), then
# checks the result on disk. What it guards, and why:
#   - files land where and how the rest of the system expects (modes 0644/0750/0440,
#     a cron name cron will read, configs logrotate and visudo accept);
#   - a second run changes nothing -- deploys are re-run all the time;
#   - shared files keep everything that is not ours (bashrc, gitconfig, ~/.claude);
#   - host-owned files survive (.bash_local) and dropped files are removed;
#   - a hand-broken managed block stops the deploy instead of eating the file;
#   - a file failing validation is never installed;
#   - every module's plan runs on both families (dry run, OS_FAMILY preset).
# Works as root (CI containers) or not: --root runs no commands either way.
#
# USAGE: bash tests/deploy.sh
# EXIT:  0 all passed, 1 any failed
# Standalone: drives install.sh as a user would; sources neither lib/ nor configs/alias.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0 skip=0
ok()   { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
skip() { printf '  SKIP  %s\n' "$1"; skip=$((skip + 1)); }
check() { local label="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$label"; else bad "$label"; fi; }
mode()  { stat -c %a "$1" 2>/dev/null; }

# The person being set up: ourselves -- or, as root (CI containers), nobody: the sudo
# module rightly refuses to grant rules to root.
DEPLOY_USER="$(id -un)"
[[ "$DEPLOY_USER" == root ]] && DEPLOY_USER=nobody
export DEPLOY_USER DEPLOY_HOME=/home/tester NO_COLOR=1
export XDG_STATE_HOME="$TMP/state"           # keep test logs and backups out of ~
deploy() { local root="$1"; shift; bash "$ROOT/install.sh" --root "$root" -y "$@" 2>&1; }
changes() { grep -cE '\] (installed|updated|removed) ' <<< "$1"; }

seed() {
    mkdir -p "$1/etc"
    printf '%s\n' '# distro bashrc' 'alias ll="ls -l"' '' \
        '# --- Shell alias modules (/etc/profile.d/.alias) ---' \
        '[ -f /etc/profile.d/.alias/.bash_aliases ] && source /etc/profile.d/.alias/.bash_aliases' '' \
        'PROMPT_COMMAND=build_ps1' > "$1/etc/bash.bashrc"
    cp "$1/etc/bash.bashrc" "$1/etc/bashrc"
    printf '[http]\n\tproxy = http://proxy.example:3128\n' > "$1/etc/gitconfig"
}

# --- 1. A first deploy --------------------------------------------------------------
echo "== first deploy: shell maint sudo claude =="
S="$TMP/host"
seed "$S"
out=$(deploy "$S" shell maint sudo claude)
check "install.sh exits 0" grep -q 'Done: shell maint sudo claude' <<< "$out"
[[ "$(grep -c '' <<< "$out")" -gt 0 ]] || bad "no output"

A="$S/etc/profile.d/.alias"
check "library deployed, 0644" test "$(mode "$A/.bash_env")" = 644
check "every module the entry point lists is there" bash -c "for m in env ui prompt functions pkg disk git nginx mongo nvm; do test -f '$A'/.bash_\$m || exit 1; done"
check "templates stay behind (.bash_local.example)" test ! -e "$A/.bash_local.example"

BRC="$S/etc/bash.bashrc"
[[ -f /etc/redhat-release ]] && BRC="$S/etc/bashrc"
check "hook block written once" test "$(grep -c '^# >>> dotfiles:hook >>>$' "$BRC")" = 1
check "hook records the checkout" grep -q "DOTFILES_ROOT=\"$ROOT\"" "$BRC"
check "legacy loader removed" bash -c "! grep -q -e 'Shell alias modules' -e 'PROMPT_COMMAND=build_ps1' '$BRC'"
check "distro content kept" grep -q 'alias ll="ls -l"' "$BRC"
check "gitconfig: existing setting kept" test "$(git config -f "$S/etc/gitconfig" http.proxy)" = http://proxy.example:3128
check "gitconfig: defaults added" test "$(git config -f "$S/etc/gitconfig" init.defaultBranch)" = main

check "sbin scripts 0750" test "$(mode "$S/usr/local/sbin/sys-maint.sh")" = 750
check "logrotate config 0644" test "$(mode "$S/etc/logrotate.d/dotfiles")" = 644
check "cron file 0644, no dot in its name" bash -c "test \"\$(stat -c %a '$S/etc/cron.d/dotfiles-maint')\" = 644"
check "cron file ends with a newline" test -z "$(tail -c1 "$S/etc/cron.d/dotfiles-maint")"
check "log directory created" test -d "$S/var/log/dotfiles"
if command -v logrotate >/dev/null; then
    check "logrotate accepts the deployed config" logrotate -d -s "$TMP/lr.state" "$S/etc/logrotate.d/dotfiles"
else
    skip "logrotate not installed"
fi

SUDOERS="$S/etc/sudoers.d/dotfiles-${DEPLOY_USER//[^A-Za-z0-9_-]/_}"
check "sudoers rendered for the user, 0440" bash -c "test \"\$(stat -c %a '$SUDOERS')\" = 440 && grep -q '^$DEPLOY_USER ALL' '$SUDOERS' && ! grep -q __DEPLOY_USER__ '$SUDOERS'"
if command -v visudo >/dev/null; then
    check "visudo accepts it" visudo -cqf "$SUDOERS"
else
    skip "visudo not installed"
fi

C="$S/home/tester/.claude"
check "claude config deployed" test -f "$C/CLAUDE.md" -a -f "$C/skills/shadcn-refactor/SKILL.md"
check "claude hooks executable" test -x "$C/hooks/block-bash-bypass.sh"
check "claude dirs keep a manifest" test -s "$C/skills/.dotfiles-manifest"

check "the deployed library loads in a strict shell" env -i PATH=/usr/bin:/bin HOME="$TMP" bash --norc --noprofile -c "set -euo pipefail; source '$A/.bash_aliases'; declare -F sys_maintain ntp_sync"
check "the maintenance scripts parse" bash -n "$S/usr/local/sbin/sys-maint.sh"

# --- 2. Idempotent ------------------------------------------------------------------------
echo ""
echo "== second deploy =="
out=$(deploy "$S" shell maint sudo claude)
n=$(changes "$out")
check "changes nothing (${n} changes)" test "$n" = 0

# --- 3. Host files and dropped files ---------------------------------------------------------
echo ""
echo "== host-owned and dropped files =="
echo 'MY_SETTING=1' > "$A/.bash_local"
echo '# a module the repo dropped' > "$A/.bash_retired"
mkdir -p "$C/skills/from-a-plugin" && echo x > "$C/skills/from-a-plugin/SKILL.md"
echo old > "$C/agents/retired.md" && echo retired.md >> "$C/agents/.dotfiles-manifest"
out=$(deploy "$S" shell claude)
check ".bash_local survives a redeploy" grep -q MY_SETTING "$A/.bash_local"
check "a dropped module is removed" test ! -e "$A/.bash_retired"
check "...and backed up first" bash -c "ls '$S'/var/backups/dotfiles/*/etc/profile.d/.alias/.bash_retired"
check "another tool's skill is left alone" test -f "$C/skills/from-a-plugin/SKILL.md"
check "a dotfiles file dropped from the repo is removed" test ! -e "$C/agents/retired.md"

# --- 4. Refusals ----------------------------------------------------------------------------
echo ""
echo "== refusals =="
B="$TMP/broken-block"
seed "$B"
for f in "$B/etc/bash.bashrc" "$B/etc/bashrc"; do printf '# >>> dotfiles:hook >>>\nhand edit, end marker lost\nalias keep=me\n' >> "$f"; done
before=$(md5sum "$B/etc/bash.bashrc" "$B/etc/bashrc")
if deploy "$B" shell >/dev/null; then bad "a begin marker without an end marker stops the deploy"; else ok "a begin marker without an end marker stops the deploy"; fi
check "...and leaves the file as it was" test "$(md5sum "$B/etc/bash.bashrc" "$B/etc/bashrc")" = "$before"

# A copy of the repo with a cron file cron would silently skip (a dot in its name)
R="$TMP/repo"
mkdir -p "$R" && (cd "$ROOT" && tar --exclude=.git -cf - .) | (cd "$R" && tar -xf -)
echo '* * * * * root true' > "$R/configs/cron.d/bad.name"
V="$TMP/validate"
seed "$V"
bash "$R/install.sh" --root "$V" -y shell >/dev/null 2>&1
if bash "$R/install.sh" --root "$V" -y maint >/dev/null 2>&1; then bad "a cron file failing validation stops the deploy"; else ok "a cron file failing validation stops the deploy"; fi
check "...and is never installed" test ! -e "$V/etc/cron.d/bad.name"
if bash "$ROOT/install.sh" --root "$TMP/x" nosuchmodule >/dev/null 2>&1; then bad "an unknown module is refused"; else ok "an unknown module is refused"; fi

# --- 5. Every module's plan, both families ---------------------------------------------------
echo ""
echo "== dry runs =="
D="$TMP/dry"
mkdir -p "$D"
export DB_PASSWORD=test-only STATIC_IP=10.0.0.5 GATEWAY=10.0.0.1 DNS_SERVERS="1.1.1.1 8.8.8.8" NETWORK_INTERFACE=eth0
mapfile -t all < <(bash "$ROOT/install.sh" --list | awk 'NF && $1 !~ /^\[/ {print $1}' | grep -vx iso)
for fam in "debian ubuntu 22.04" "debian ubuntu 20.04" "rhel rocky 9.4" "rhel rhel 9.4"; do
    read -r f id v <<< "$fam"
    if out=$(OS_FAMILY="$f" OS_ID="$id" OS_VERSION="$v" bash "$ROOT/install.sh" -n --root "$D" "${all[@]}" 2>&1); then
        ok "${id} ${v}: all ${#all[@]} modules plan cleanly"
    else
        bad "${id} ${v}: dry run failed"; tail -5 <<< "$out" | sed 's/^/        /'
    fi
done
check "a dry run writes nothing, even into its sandbox" test -z "$(find "$D" -type f)"

echo ""
echo "Assertions: ${pass} passed, ${fail} failed, ${skip} skipped"
(( fail == 0 )) || { echo "DEPLOY: FAIL"; exit 1; }
echo "DEPLOY: PASS"
