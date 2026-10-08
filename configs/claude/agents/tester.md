---
description: Write and run unit tests for the active file via the tester subagent
---
Dispatch the `tester` subagent (Agent tool, `subagent_type: "tester"`) to write and run unit tests per the project's testing conventions.

- Default target: $ACTIVE_FILE. If $ARGUMENTS names a file or function, target that instead.
- The subagent must actually run the suite (`pnpm run test` / `pnpm run test:unit`) and report real pass/fail output — relay it verbatim, including any skips or failures. Do not claim a green run the subagent did not observe.
