#!/usr/bin/env bash
# =============================================================================
# tests/run.sh — Test Runner (all suites)
# =============================================================================
# Discovers and runs every test suite in this directory, then prints a
# combined summary. A suite is any tests/*.sh script except this runner;
# each must exit 0 on pass and non-zero on fail. A failing suite does not
# stop the run — all suites always execute.
#
# USAGE:
#   bash tests/run.sh           # no root required
#
# EXIT CODE: 0 = all suites passed, 1 = at least one failed
# =============================================================================
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare -a passed=() failed=()

for suite in "$TESTS_DIR"/*.sh; do
  name="$(basename "$suite")"
  [[ "$name" == "run.sh" ]] && continue

  echo "======================================================================"
  echo ">> $name"
  echo "======================================================================"
  if bash "$suite"; then
    passed+=("$name")
  else
    failed+=("$name")
  fi
  echo ""
done

echo "======================================================================"
echo "Suites: ${#passed[@]} passed, ${#failed[@]} failed"
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "Failed: ${failed[*]}"
  echo "TESTS: FAIL"
  exit 1
fi
echo "TESTS: PASS"
