#!/usr/bin/env bash
# =============================================================================
# system/diskclean.sh — Reclaim Disk Space From Regenerable Caches
# =============================================================================
# Finds and removes build/tool caches that can be regenerated, reports exactly
# what it will free BEFORE touching anything, and asks for confirmation.
#
# Nothing here is a source of truth: every candidate is either a compiler cache,
# a package manager's download cache, or a binary that cannot execute on this
# machine. Source code, git state and installed packages are never touched.
#
# TIERS (each includes the ones above it):
#   (default)   free       Rust incremental caches + browser binaries built for
#                          the wrong CPU architecture. Costs nothing but a
#                          slightly slower next compile.
#   --cache     cheap      npm / pnpm / yarn download caches. Re-downloaded on
#                          demand, so this costs bandwidth on the next install.
#   --deep      expensive  `cargo clean` on every Rust project found. Frees the
#                          most by far, but the next build of each project is a
#                          full rebuild from scratch.
#
# USAGE:
#   bash system/diskclean.sh              # tier 1, asks before deleting
#   bash system/diskclean.sh -n           # dry run: report only, delete nothing
#   bash system/diskclean.sh -y           # tier 1, no prompt (for cron)
#   bash system/diskclean.sh --cache      # + package manager caches
#   bash system/diskclean.sh --deep -n    # see what a full cargo clean would free
#   bash system/diskclean.sh --root ~/x   # limit the project scan to one tree
#
# EXIT CODE: 0 = finished (including "nothing to do"), 1 = bad usage or refused
#
# NOTE: every deletion is constrained to $HOME by _is_safe_target(). A candidate
#       that fails that check is skipped loudly rather than silently.
# =============================================================================
set -uo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/env.sh
source "$DOTFILES_ROOT/lib/env.sh"
# shellcheck source=../lib/log.sh
source "$DOTFILES_ROOT/lib/log.sh"

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
TIER="free"          # free | cheap | expensive
DRY_RUN=0
ASSUME_YES=0
SCAN_ROOT="$HOME"

usage() {
  awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "${BASH_SOURCE[0]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    -y|--yes)     ASSUME_YES=1 ;;
    --cache)      [[ "$TIER" == "expensive" ]] || TIER="cheap" ;;
    --deep)       TIER="expensive" ;;
    --root)       shift; SCAN_ROOT="${1:-}" ;;
    -h|--help)    usage; exit 0 ;;
    *)            log_warn "unknown option: $1"; usage; exit 1 ;;
  esac
  shift
done

[[ -d "$SCAN_ROOT" ]] || log_error "scan root does not exist: $SCAN_ROOT"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# Bytes consumed by a path, 0 if it is missing.
_size_of() {
  [[ -e "$1" ]] || { echo 0; return; }
  du -sb "$1" 2>/dev/null | cut -f1 || echo 0
}

_human() {
  local b="${1:-0}"
  if   (( b >= 1073741824 )); then awk -v b="$b" 'BEGIN{printf "%.1fG", b/1073741824}'
  elif (( b >= 1048576 ));    then awk -v b="$b" 'BEGIN{printf "%.0fM", b/1048576}'
  elif (( b >= 1024 ));       then awk -v b="$b" 'BEGIN{printf "%.0fK", b/1024}'
  else printf '%dB' "$b"
  fi
}

_avail_bytes() { df -P -B1 "$HOME" | awk 'NR==2 {print $4}'; }

# Refuse to delete anything that is not a reasonably deep path inside $HOME.
# This is the last line of defence if a find expression ever goes wrong.
_is_safe_target() {
  local p="$1"
  [[ "$p" == "$HOME"/* ]] || return 1
  [[ "$p" != "$HOME" ]]   || return 1
  # At least two path components below $HOME, so ~/foo alone never qualifies.
  local rel="${p#"$HOME"/}"
  [[ "$rel" == */* ]]
}

# The substring `file` prints for a binary matching this machine's CPU.
_native_arch_token() {
  case "$(uname -m)" in
    aarch64|arm64) echo "ARM aarch64" ;;
    x86_64|amd64)  echo "x86-64" ;;
    armv7l|armv6l) echo "ARM, EABI" ;;
    *)             echo "" ;;
  esac
}

# True when $1 holds an ELF executable built for a DIFFERENT CPU than ours, i.e.
# a download that can never run here. Uncertainty always answers false.
_is_foreign_binary_tree() {
  local dir="$1" token bin
  token="$(_native_arch_token)"
  [[ -n "$token" ]] || return 1
  command -v file >/dev/null 2>&1 || return 1
  bin="$(find "$dir" -type f -executable -name '*chrome*' -o -type f -executable -name '*firefox*' 2>/dev/null | head -1)"
  [[ -n "$bin" && -f "$bin" ]] || return 1
  local desc
  desc="$(file -b "$bin" 2>/dev/null)"
  [[ "$desc" == *ELF* ]] || return 1
  [[ "$desc" != *"$token"* ]]
}

# -----------------------------------------------------------------------------
# Plan
# -----------------------------------------------------------------------------
PLAN_PATHS=()
PLAN_LABELS=()
PLAN_BYTES=()
PLAN_MODE=()         # rm | cargo-clean

# True when $1 is already covered by a planned entry, which would otherwise
# double-count (an incremental cache lives inside the target dir above it).
_already_covered() {
  local p="$1" existing
  (( ${#PLAN_PATHS[@]} )) || return 1
  for existing in "${PLAN_PATHS[@]}"; do
    [[ "$p" == "$existing" || "$p" == "$existing"/* ]] && return 0
  done
  return 1
}

plan_add() {
  local path="$1" label="$2" mode="${3:-rm}" bytes
  [[ -e "$path" ]] || return 0
  # --root means --root: a candidate outside the scanned tree is never in scope,
  # even one this script knows about by absolute path.
  if [[ "$path" != "$SCAN_ROOT" && "$path" != "$SCAN_ROOT"/* ]]; then
    return 0
  fi
  _already_covered "$path" && return 0
  if ! _is_safe_target "$path"; then
    log_warn "skipping unsafe path: $path"
    return 0
  fi
  bytes="$(_size_of "$path")"
  (( bytes > 0 )) || return 0
  PLAN_PATHS+=("$path")
  PLAN_LABELS+=("$label")
  PLAN_BYTES+=("$bytes")
  PLAN_MODE+=("$mode")
}

collect_tier_free() {
  # Rust incremental caches — pure compile-speed state, never a build product.
  local d
  while IFS= read -r -d '' d; do
    plan_add "$d" "rust incremental cache"
  done < <(find "$SCAN_ROOT" -maxdepth 5 -mindepth 1 -name '.*' -prune -o \
             -type d -name incremental -path '*/target/*' -print0 2>/dev/null)

  # Browser downloads for the wrong architecture (puppeteer/playwright do this
  # when a postinstall guesses the platform wrong). These are $HOME-anchored, so
  # plan_add drops them automatically whenever --root points somewhere else.
  local c
  for c in "$HOME/.cache/puppeteer" "$HOME/.cache/ms-playwright"; do
    [[ -d "$c" ]] || continue
    if _is_foreign_binary_tree "$c"; then
      plan_add "$c" "browser built for the wrong CPU (cannot execute here)"
    fi
  done

  # Leftovers from builds that were interrupted partway.
  while IFS= read -r -d '' d; do
    plan_add "$d" "interrupted build leftovers"
  done < <(find "$SCAN_ROOT" -maxdepth 6 -mindepth 1 -name '.*' -prune -o \
             \( -name '*.assembling' -o -name 'incremental-*.tmp' \) \
             -print0 2>/dev/null)
}

collect_tier_cheap() {
  plan_add "$HOME/.npm/_cacache"   "npm download cache (re-downloaded on demand)"
  plan_add "$HOME/.cache/pnpm"     "pnpm metadata cache"
  plan_add "$HOME/.cache/yarn"     "yarn download cache"
  plan_add "$HOME/.cache/typescript" "typescript version cache"
}

collect_tier_expensive() {
  command -v cargo >/dev/null 2>&1 || { log_warn "cargo not found; skipping --deep"; return; }
  local t proj
  while IFS= read -r -d '' t; do
    proj="$(dirname "$t")"
    [[ -f "$proj/Cargo.toml" ]] || continue
    plan_add "$t" "full rust build dir for $(basename "$proj") — NEXT BUILD IS FROM SCRATCH" "cargo-clean"
  done < <(find "$SCAN_ROOT" -maxdepth 3 -mindepth 1 -name '.*' -prune -o \
             -type d -name target -print0 2>/dev/null)
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
log_section "Disk cleanup — tier: $TIER"

BEFORE="$(_avail_bytes)"
log_info "free space now: $(_human "$BEFORE")"
log_info "scanning $SCAN_ROOT ..."

# Widest scope first: a planned `cargo clean` already covers the incremental
# caches nested inside it, so collecting in this order keeps the total honest.
[[ "$TIER" == "expensive" ]] && collect_tier_expensive
[[ "$TIER" == "cheap" || "$TIER" == "expensive" ]] && collect_tier_cheap
collect_tier_free

if [[ "${#PLAN_PATHS[@]}" -eq 0 ]]; then
  log_success "nothing to reclaim at this tier."
  exit 0
fi

TOTAL=0
for b in "${PLAN_BYTES[@]}"; do TOTAL=$(( TOTAL + b )); done

echo ""
printf '  %-10s %-52s %s\n' "SIZE" "PATH" "WHAT IT IS"
printf '  %-10s %-52s %s\n' "----" "----" "----------"
for i in "${!PLAN_PATHS[@]}"; do
  printf '  %-10s %-52s %s\n' \
    "$(_human "${PLAN_BYTES[$i]}")" \
    "${PLAN_PATHS[$i]/#$HOME/\~}" \
    "${PLAN_LABELS[$i]}"
done
echo ""
log_info "total reclaimable: $(_human "$TOTAL")"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log_success "dry run — nothing was deleted."
  exit 0
fi

if [[ "$ASSUME_YES" -ne 1 ]]; then
  if [[ ! -t 0 ]]; then
    log_error "not a terminal and -y was not given; refusing to delete unprompted."
  fi
  read -r -p "  Delete all of the above? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || { log_warn "aborted; nothing was deleted."; exit 1; }
fi

FREED=0
for i in "${!PLAN_PATHS[@]}"; do
  path="${PLAN_PATHS[$i]}"
  _is_safe_target "$path" || { log_warn "skipping unsafe path: $path"; continue; }
  if [[ "${PLAN_MODE[$i]}" == "cargo-clean" ]]; then
    if cargo clean --manifest-path "$(dirname "$path")/Cargo.toml" >/dev/null 2>&1; then
      FREED=$(( FREED + PLAN_BYTES[i] ))
      log_info "cleaned $(basename "$(dirname "$path")")"
    else
      log_warn "cargo clean failed for $path"
    fi
  elif rm -rf -- "$path"; then
    FREED=$(( FREED + PLAN_BYTES[i] ))
  else
    log_warn "could not remove $path"
  fi
done

AFTER="$(_avail_bytes)"
log_success "reclaimed $(_human "$FREED"); free space $(_human "$BEFORE") -> $(_human "$AFTER")"
