---
description: Add or complete JSDoc and inline comments for the active file
---
Add or complete JSDoc and inline comments for $ACTIVE_FILE following these rules:

- Write JSDoc for every **non-obvious** exported function/component and every public API (matches CLAUDE.md). Skip trivial one-line exports whose signature already says everything — forced JSDoc on the obvious is noise.
- Use standard tags: `@param`, `@returns`, `@example`. For optional props use `[props.xxx]`; include defaults where applicable: `[props.align='start']`.
- Add inline comments only where the **why** is non-obvious (hidden constraints, subtle invariants, workarounds) — never comment what the code already says.
- All JSDoc descriptions and inline comments must be written in **Traditional Chinese**.
- Do NOT translate domain terms (e.g. keep 抽查記錄表, 編輯模版 as-is).
- Do not alter logic. Do not reformat beyond what `eslint --fix` already enforces.
- Run `pnpm exec eslint --fix` on the file when done.
