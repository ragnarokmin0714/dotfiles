#!/usr/bin/env bash
# block-bash-bypass.sh — PreToolUse guard for the Bash tool.
#
# Blocks destructive patterns the settings.json glob deny list cannot catch,
# because they smuggle a denied action through an allowed tool:
#   find -delete / -exec, awk system(), xargs rm, sh -c / bash -c wrappers.
#
# Protocol: reads the PreToolUse event JSON on stdin and, on a match, prints a
# PreToolUse "deny" decision (hookSpecificOutput) so Claude sees the reason.
# This is defense-in-depth, NOT a security sandbox — a determined caller can
# still evade regex matching.

set -uo pipefail

payload="$(cat)"

# Extract tool_input.command. Prefer jq (per Claude Code docs); fall back to
# python3. If neither exists, degrade open (allow) with a warning rather than
# blocking every Bash call.
if command -v jq >/dev/null 2>&1; then
    cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')"
elif command -v python3 >/dev/null 2>&1; then
    cmd="$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))')"
else
    echo "PreToolUse guard: neither jq nor python3 found — skipping check" >&2
    exit 0
fi

# Each entry: <extended-regex>|<human-readable reason>.
deny_patterns=(
    'find[[:space:]].*-delete|find with -delete'
    'find[[:space:]].*-exec(dir)?[[:space:]]|find with -exec/-execdir'
    '\b(g?awk)\b.*system\(|awk/gawk system() shelling out'
    'xargs[[:space:]].*\brm\b|xargs piping into rm'
    '\b(ba)?sh[[:space:]]+-c\b|sh -c / bash -c wrapper'
)

# Emit a PreToolUse deny decision. Prefer jq for safe JSON encoding of the
# reason; fall back to exit-code-2 blocking when jq is unavailable.
deny() {
    local reason="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg r "$reason" \
            '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
        exit 0
    fi
    echo "BLOCKED by PreToolUse guard: ${reason}" >&2
    exit 2
}

for entry in "${deny_patterns[@]}"; do
    regex="${entry%%|*}"
    reason="${entry#*|}"
    if printf '%s' "$cmd" | grep -Eq "$regex"; then
        deny "${reason} (command: ${cmd})"
    fi
done

exit 0
