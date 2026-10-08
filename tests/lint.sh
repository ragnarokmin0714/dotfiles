#!/usr/bin/env bash
# =============================================================================
# tests/lint.sh — static checks: syntax, shellcheck, and the repo's own rules
# =============================================================================
# 1. bash -n on every shell file
# 2. shellcheck (severity >= warning; policy in .shellcheckrc)
# 3. policy -- the conventions in .claude/CLAUDE.md that code can check, checked by
#    code rather than by memory:
#      - the runtime library asks questions only through .bash_ui (confirm / ask /
#        radioselect / multiselect): no hand-rolled `read -p` prompts elsewhere;
#      - root commands go through $SUDO, never a literal `sudo`, so they also run
#        where sudo is absent and as root;
#      - every deploy module declares @desc and @order and starts through lib/core.sh.
#
# USAGE: bash tests/lint.sh        (no root needed)
# EXIT:  0 clean, 1 at least one finding
# Standalone on purpose: sources neither lib/ nor configs/alias, so a broken
# library cannot break the check that is meant to catch it.
# =============================================================================
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

mapfile -t SCRIPTS < <(ls install.sh config.sh config.local.example.sh lib/*.sh modules/*/main.sh \
    configs/sbin/* configs/claude/hooks/*.sh tests/*.sh)
mapfile -t LIBRARY < <(ls configs/alias/.bash_*)
fail=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=1; }

echo "== bash -n =="
for f in "${SCRIPTS[@]}" "${LIBRARY[@]}"; do
    if bash -n "$f" 2>&1; then ok "$f"; else bad "$f"; fi
done

echo ""
echo "== shellcheck =="
SHELLCHECK="$(command -v shellcheck || echo "$HOME/.local/bin/shellcheck")"
if [[ ! -x "$SHELLCHECK" ]]; then
    bad "shellcheck not found -- install it (toolkit: pe shellcheck) or https://github.com/koalaman/shellcheck"
else
    # -x follows `source` lines that name a repo path (# shellcheck source=...)
    if "$SHELLCHECK" -x -S warning "${SCRIPTS[@]}"; then ok "${#SCRIPTS[@]} scripts"; else fail=1; fi
    if "$SHELLCHECK" -S warning -s bash "${LIBRARY[@]}"; then ok "${#LIBRARY[@]} library modules"; else fail=1; fi
fi

echo ""
echo "== policy =="
# Questions go through .bash_ui. `read -r -a`, `read -rs -n1` (the engines) and reads
# from pipes/heredocs are fine; a prompt (-p) outside .bash_ui is not.
hits=$(grep -nE '\bread[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-[A-Za-z]*p' "${LIBRARY[@]}" | grep -v '^configs/alias/.bash_ui:' || true)
if [[ -z "$hits" ]]; then ok "prompts only in .bash_ui"; else bad "hand-rolled prompt (use confirm / ask / radioselect):"; echo "$hits"; fi

# A literal sudo at the start of a command, in the library or the maintenance scripts.
# Messages that tell the user what to type ("-> sudo growpart ...") are inside quotes,
# and `sudo -v` (refresh credentials, for non-root only) is allowed.
# Quoted text is blanked before matching, comments are skipped.
hits=$(awk '
    { line = $0; gsub(/"[^"]*"/, "\"\"", line); gsub(/'"'"'[^'"'"']*'"'"'/, "", line) }
    line ~ /^[[:space:]]*#/ { next }
    line ~ /(^|[;&|(]|\$\()[[:space:]]*sudo[[:space:]]/ && line !~ /sudo -v/ { print FILENAME ":" FNR ": " $0 }
' "${LIBRARY[@]}" configs/sbin/*)
if [[ -z "$hits" ]]; then ok "root commands use \$SUDO"; else bad "literal sudo (use \$SUDO):"; echo "$hits"; fi

for m in modules/*/main.sh; do
    grep -q '^# @desc ' "$m" && grep -q '^# @order ' "$m" \
        && grep -q 'lib/core.sh' "$m" && ok "$m header" \
        || bad "$m: needs '# @desc', '# @order' and to source lib/core.sh"
done

echo ""
if (( fail )); then echo "LINT: FAIL"; exit 1; fi
echo "LINT: PASS"
