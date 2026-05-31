# GitHub Copilot Instructions

You are an AI assistant contributing to this repository. Follow these rules strictly.
**Priority order**: File-level > Folder-level > This file.

---

## 1. General Principles

- **Design philosophy**: YAGNI > KISS > pragmatic DRY. Prefer clarity over cleverness.
- **Scope**: Generate production-ready code only — no demo or placeholder code. Keep changes within the requested scope.
- **Architecture**: Enforce `Controller (I/O, validation)` → `Service (business logic)` → `Repository/Infra (external/DB)`. No circular dependencies.
- **Cross-platform**: All shell scripts must support both Ubuntu/Debian (`apt`) and Rocky Linux/RHEL (`dnf`). Use `command -v` to guard optional tools (e.g., `npm`, `pnpm`).

---

## 2. Forbidden Actions — Require Explicit Confirmation

Never perform the following without explicit user confirmation:

- Destructive shell commands: `rm -rf`, `git reset --hard`, `DROP TABLE`, etc.
- Modifying files outside `/etc/moneytek/construction_pmis`.
- Installing global packages: `npm install -g`, `pnpm add -g`, `pip install --user`.
- Pushing, amending, or deleting branches/commits directly.
- Bypassing safety checks: `--no-verify`, `--force`, etc.

---

## 3. Coding Style & Conventions

**Naming:**
- `camelCase` — variables, functions
- `PascalCase` — classes, types, components
- `UPPER_SNAKE_CASE` — constants

**Structure:**
- Use early returns and guard clauses (Fail-Fast). Avoid deep nesting.
- Follow the Single Responsibility Principle.
- Max **50 lines** per function. Max **400 lines** per file (hard ceiling; split if exceeded).

**Formatting (JS/TS/JSX/TSX):**
After modifying any JS/TS/JSX/TSX file, run these steps **in order** before declaring completion:

1. `pnpm exec eslint --fix <file>` — resolve all remaining errors that `--fix` cannot auto-correct.
2. Only after ESLint reports zero errors: `pnpm exec prettier --write <file>`.

> **Exception**: `eslint.config.mjs` — run ESLint only; do **not** run Prettier on this file.

**Languages:**
- TypeScript: strict mode, avoid `any`.
- Python: PEP 8, type hints required.
- Java: use interfaces, correct casing.

**Package manager**: Use `pnpm` exclusively for all Node.js operations (`pnpm install`, `pnpm run`, `pnpm exec`). Do **not** use `npm` or `yarn` — it will corrupt `pnpm-lock.yaml`.

---

## 4. Comments & Documentation

- Explain **why**, not what. Do not comment obvious code.
- Write JSDoc/docstrings for all non-obvious functions and public APIs.
- **All comments, JSDoc, and docstrings must be written in Traditional Chinese.**
- After completing a feature (Repo / API Route / Service / UI), check if a corresponding `.github/specs/*.spec.md` or `.github/skills/*/SKILL.md` exists. If so, **update it to reflect the implemented behavior** — do not wait to be asked.

---

## 5. Error Handling & Security

**Error handling:**
- Never swallow errors silently.
- Throw custom, typed error objects with actionable context.
- Propagate async errors cleanly.
- Use centralized logging — never `console.log` in production code.

**Security:**
- Validate and sanitize all external inputs (prefer allow-lists).
- Store secrets and credentials in environment variables.
- Follow the principle of least privilege.
- Never expose internal model schemas directly in API responses — use DTOs.

---

## 6. Testing

- **Pattern**: Arrange-Act-Assert (AAA).
- **Quality**: Write deterministic tests. Mock/stub all external dependencies — never hit real databases or APIs in unit tests.
- **Coverage**: Include edge cases and error paths for all new functions.
- **Execution**: Run tests via `pnpm run test` or `pnpm run test:unit`. Do not run redundant install commands before testing. Do not wrap tests in graphical launchers (e.g., `xvfb-maybe`) unless explicitly required.

**Importing vs. copying into test files:**
Before inlining any constant or function, check if the source module is safe to import directly.

| Safe to import? | Condition |
|---|---|
| Yes | No `'use client'`, no React hooks, no JSX, no CSS module imports, no Next.js-specific APIs |
| No — copy instead | Any of the above is present |

If you copy, document why with a comment (e.g., `// addCamera.js has React component imports — STATUS_MAP must be inlined`).

---

## 7. Process & Behavior

- **Read before writing**: Before adding code, read exports, immediate callers, and shared utilities. If you are unsure why code is structured a certain way, ask — do not assume it is safe to change.
- **Surface conflicts**: If two patterns contradict, pick one (prefer the more recent or more tested), explain why, and flag the other for cleanup. Do not blend conflicting patterns.
- **Match conventions**: Conform to the codebase's existing style over personal preference. If a convention seems harmful, surface it — do not fork silently.
- **Fail loud**: Do not report "Completed" if anything was skipped silently. Do not report "Tests pass" if any were skipped. Surface uncertainty — never hide it.

---

## 8. Output & Collaboration

- **Format**: Explanation first → complete code block → test cases. Include all necessary imports.
- **Language**: Respond to the user in English. Do **not** translate project domain terms (e.g., keep 抽查記錄表, 編輯模版 as-is).
- **Git**: Use Conventional Commits (`feat: ...`, `fix: ...`). Prefer small, composable commits for easy review.
- **Dependencies**: Justify any new dependency. Prefer the standard library or existing project libraries. Avoid heavy packages for trivial tasks.
- **Performance**: Avoid O(n²) or worse algorithms on large datasets. Prefer lazy evaluation or streaming for bulk operations. Avoid N+1 query patterns.

---

## 9. Framework & Stack Conventions

### Next.js (App Router)

- Default to Server Components. Add `'use client'` only when required (hooks, browser APIs, event handlers).
- Unwrap dynamic route params with `React.use(params)` — do not access `params.xxx` directly in async page components.
- Keep initial data fetching in Server Components or the service layer. Avoid `useEffect` for data that can be loaded server-side.
- API route handlers live in `src/app/api/`. Follow REST conventions and always return typed responses via DTOs.

### SCSS Modules

- Import mixins via `@use 'styles/scss/mixins' as m`. Use `@include m.mobile` for the ≤576px breakpoint.
- Use CSS custom properties (`--var-name`) for design tokens shared across components. Do not hardcode colors or sizes.
- No global side-effecting styles inside `.module.scss` files — keep modules fully scoped.
- Class names in `.module.scss` use `camelCase` to match JS property access (e.g., `styles.myClass`).

### Redux

- Read state exclusively via `useSelector`. Never call `store.getState()` directly inside React components.
- Co-locate selectors with their slice file. Do not define inline selectors inside components.