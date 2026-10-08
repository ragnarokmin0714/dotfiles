#!/usr/bin/env bash
# =============================================================================
# tests/lint.sh — Static Checks (bash -n + shellcheck)
# =============================================================================
# Runs two static passes over every shell file in the repo:
#   1. bash -n     — pure syntax check
#   2. shellcheck  — static analysis, severity >= warning
#                    (repo policy lives in the root .shellcheckrc)
#
# USAGE:
#   bash tests/lint.sh          # no root required
#
# EXIT CODE: 0 = all clean, 1 = at least one finding
#
# NOTE: deliberately standalone — does not source lib/ so it still runs
#       when lib/ itself is the thing that's broken.
# =============================================================================
set -uo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOTFILES_ROOT" || exit 1

# Files under test: executable scripts + sourced alias modules
SCRIPTS=(install.sh lib/*.sh system/*.sh tests/*.sh)
MODULES=(configs/alias/.bash_*)

fail=0

echo "== bash -n (syntax) =="
for f in "${SCRIPTS[@]}" "${MODULES[@]}"; do
  if bash -n "$f" 2>&1; then
    printf '  ok    %s\n' "$f"
  else
    printf '  FAIL  %s\n' "$f"
    fail=1
  fi
done

echo ""
echo "== shellcheck (severity >= warning) =="
SHELLCHECK="$(command -v shellcheck || true)"
if [[ -z "$SHELLCHECK" && -x "$HOME/.local/bin/shellcheck" ]]; then
  SHELLCHECK="$HOME/.local/bin/shellcheck"
fi
if [[ -z "$SHELLCHECK" ]]; then
  echo "FAIL: shellcheck not found (looked in PATH and ~/.local/bin)." >&2
  echo "      Via the alias toolkit:  pe -m apt shellcheck   (or: sys_toolkit -o)" >&2
  echo "      Manual install:         https://github.com/koalaman/shellcheck#installing" >&2
  exit 1
fi

# Executable scripts carry their own shebang; alias modules are sourced
# files without one, so tell shellcheck they are bash.
if "$SHELLCHECK" -S warning "${SCRIPTS[@]}"; then
  printf '  ok    %d script(s)\n' "${#SCRIPTS[@]}"
else
  fail=1
fi
if "$SHELLCHECK" -S warning -s bash "${MODULES[@]}"; then
  printf '  ok    %d alias module(s)\n' "${#MODULES[@]}"
else
  fail=1
fi

echo ""
if [[ "$fail" -ne 0 ]]; then
  echo "LINT: FAIL"
  exit 1
fi
echo "LINT: PASS"
