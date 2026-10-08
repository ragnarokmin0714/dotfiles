#!/usr/bin/env bash
# =============================================================================
# tests/smoke.sh — Smoke Test for configs/alias Modules
# =============================================================================
# Sources configs/alias/.bash_aliases in a CLEAN bash process (env -i,
# --norc --noprofile) and asserts the public surface is actually defined:
#
#   - key functions from every module (env / git / functions / pkg / nginx)
#   - key aliases
#   - _pkg_manager resolves to apt or dnf on this host
#   - log framework emits the message it was given
#   - build_ps1 runs and produces a non-empty PS1
#   - sourcing the entry point twice is safe (idempotent)
#
# USAGE:
#   bash tests/smoke.sh         # no root required
#
# EXIT CODE: 0 = all assertions passed, 1 = at least one failed
#
# NOTE: deliberately standalone — does not source lib/ so the test harness
#       never depends on code adjacent to the code under test.
# =============================================================================
set -uo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRY="$DOTFILES_ROOT/configs/alias/.bash_aliases"

if [[ ! -f "$ENTRY" ]]; then
  echo "FAIL: entry point not found: $ENTRY" >&2
  exit 1
fi

# All assertions run inside one clean bash: no inherited env, rc files,
# aliases, or functions — only HOME/PATH/TERM/USER survive.
env -i \
  HOME="$HOME" \
  USER="${USER:-$(id -un)}" \
  PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  TERM=dumb \
  ENTRY="$ENTRY" \
  bash --noprofile --norc << 'EOF'
pass=0
fail=0

t_ok()   { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
t_fail() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

echo "== source entry point =="
if source "$ENTRY"; then
  t_ok "source $ENTRY"
else
  t_fail "source $ENTRY"
  echo "SMOKE: FAIL ($fail failed)"
  exit 1
fi

echo ""
echo "== functions defined =="
FUNCS=(
  # .bash_env
  styled git_prompt build_ps1
  log_ok log_err log_warn log_info log_step log_head log_banner
  # .bash_git
  git_fetch_merge git_push_current_branch git_switch_and_pull
  # .bash_functions
  clean_up_disk ntp_status ntp_fix deploy_alias free_mem tz
  stop_dev reload_shell get_ip disk_usage_top
  # .bash_pkg
  _pkg_manager pkg_installed pkg_ensure pkg_remove sys_toolkit
  sys_update sys_maintain multiselect
  # .bash_nginx
  nginx_status nginx_log nginx_test_reload nginx_vhost_list
)
for fn in "${FUNCS[@]}"; do
  if declare -F "$fn" > /dev/null; then t_ok "function $fn"; else t_fail "function $fn"; fi
done

echo ""
echo "== aliases defined =="
ALIASES=(
  pi pe prm rs cud sup fm dut
  gfm gpcb gswp amend
  ntp-status ntp-fix sys-toolkit
  ngs ngl nginx-status
  cdaliases cdlog
)
for al in "${ALIASES[@]}"; do
  if alias "$al" > /dev/null 2>&1; then t_ok "alias $al"; else t_fail "alias $al"; fi
done

echo ""
echo "== behavior =="
pm="$(_pkg_manager)"
case "$pm" in
  apt | dnf) t_ok "_pkg_manager resolves to '$pm'" ;;
  *)         t_fail "_pkg_manager resolves to '$pm' (expected apt or dnf)" ;;
esac

out="$(log_ok smoke-probe 2>&1)"
if [[ "$out" == *smoke-probe* ]]; then
  t_ok "log_ok emits its message"
else
  t_fail "log_ok emits its message (got: '$out')"
fi

if build_ps1 > /dev/null 2>&1 && [[ -n "${PS1:-}" ]]; then
  t_ok "build_ps1 runs and sets PS1"
else
  t_fail "build_ps1 runs and sets PS1"
fi

if source "$ENTRY" > /dev/null 2>&1; then
  t_ok "double source is safe"
else
  t_fail "double source is safe"
fi

echo ""
echo "Assertions: $pass passed, $fail failed"
if [[ "$fail" -ne 0 ]]; then
  echo "SMOKE: FAIL"
  exit 1
fi
echo "SMOKE: PASS"
EOF
