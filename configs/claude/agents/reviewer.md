---
description: Review the current diff with the reviewer subagent (correctness + CLAUDE.md conventions)
---
Dispatch the `reviewer` subagent (Agent tool, `subagent_type: "reviewer"`) to review the current changes.

- Default scope: the working diff / current branch. If $ARGUMENTS names a file, path, or PR number, scope the review to that instead.
- The subagent is read-only; it reports findings and does not edit. Relay its findings back most-severe first, keeping its `Uncertain:` labels intact — do not re-review or silently override it.
- If the user then wants fixes applied, hand them to the `builder` subagent (`/builder`).
