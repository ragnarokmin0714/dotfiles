---
description: Before starting a task, recommend which Claude model and effort level to run it with — then stop and wait
argument-hint: "[task — default: the request just made]"
---
Do **not** start the task yet. First recommend how to run it.

**The task:** $ARGUMENTS — if empty, the request the user made just before this command.

Weigh it briefly on three things:

- **Judgment or mechanics.** Design choices, trade-offs, unclear requirements, and bugs whose cause is unknown need judgment. Renames, moves, path updates, formatting and carrying out an already-decided plan are mechanical.
- **What catches mistakes.** If builds, tests, linters or a reviewable diff will catch an error, a lighter setting is safe. If correctness rests on reasoning alone — security, concurrency, data integrity, money, anything irreversible or outward-facing — go heavier.
- **Size.** How many files, how much context must be held at once, how long the work runs.

Choose from:

- **Haiku** — small, well-specified edits that are easy to check; lookups.
- **Sonnet** — most implementation: features with a clear plan, refactors and moves, tests, docs.
- **Opus** — architecture and design decisions, hard debugging, subtle concurrency / security / data-integrity work, large cross-cutting changes.

Effort: `low` for mechanical steps; `medium` as the default; `high` when a wrong call is costly or the cause is unknown; `xhigh` / `max` only for the rare problem that resists everything else.

Reply in the user's language, short:

1. **Recommendation** — model and effort, one line.
2. **Why** — two to four bullets tied to *this* task: what is mechanical, what needs judgment, what will catch mistakes.
3. **Watch out for** — the specific traps in this task that the chosen setting must still not miss, if any.
4. **When to go heavier** — what would change the answer, if anything.
5. How to switch: `/model` (the conversation carries over).

Then stop. Start the task only after the user confirms or switches.
