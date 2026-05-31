# GitHub Copilot Instructions (Project-Level – Production-Ready)

You are an AI assistant contributing to this repository. Follow these rules strictly.
Priority: File-level > Folder-level > This file.

## 1. General Principles
- **Design**: YAGNI > KISS > pragmatic DRY. Prefer clarity over cleverness.
- **Scope**: Generate production-ready code only (no demo or placeholder code). Keep changes within requested scope.
- **Architecture**: Enforce Controller (I/O, validation) -> Service (business logic) -> Repository/Infra (external/DB). No circular dependencies.

## 2. Coding Style & Conventions
- **Naming**: `camelCase` for variables/functions, `PascalCase` for classes/types/components, `UPPER_SNAKE_CASE` for constants.
- **Structure**: Use early returns and guard clauses (Fail-Fast). Avoid deep nesting. Follow the Single Responsibility Principle.
- **Limits**: Max 50 lines per function. Max 400 lines per file (hard ceiling; split if exceeded).
- **Formatting**: 120 characters per line maximum. After modifying any JS/TS/JSX/TSX file, follow this mandatory sequence before declaring completion:
  1. Only after ESLint reports zero errors, run `pnpm exec prettier --write <file>` to apply final formatting.
  Skipping either step, or running them out of order, is not acceptable.
  2. Run `pnpm exec eslint --fix <file>` and resolve **all** remaining ESLint errors that `--fix` cannot auto-correct.
  **Exception**: `eslint.config.mjs` — run ESLint only; do NOT run Prettier on this file.
- **Languages**: TypeScript (strict, avoid `any`), Python (PEP8, type hints), Java (interfaces, correct casing).
- **Package Manager**: STRICTLY use `pnpm` for all Node.js package operations (`pnpm install`, `pnpm run`, `pnpm exec`). Do NOT use `npm` or `yarn` as it will break the lockfile (`pnpm-lock.yaml`).

## 3. Comments & Documentation
- Explain "why", not "what". Avoid commenting obvious code.
- Write JSDoc / docstrings for all non-obvious functions and public APIs.
- **Requirement**: ALL comments, JSDoc, and docstrings MUST be written in Traditional Chinese.
- **Living Docs**: After completing a feature implementation (Repo / API Route / Service / UI), check if a corresponding `.github/specs/*.spec.md` or `.github/skills/*/SKILL.md` exists. If it does, **update it to reflect the implemented behavior** without being asked.

## 4. Error Handling & Security
- **Errors**: Never swallow errors silently. Throw custom, typed error objects with actionable contexts. Propagate async errors cleanly. Use centralized logging — never `console.log` in production code.
- **Security**: Validate and sanitize all external inputs (prefer allow-lists). Use env vars for secrets/credentials. Follow least privilege. Never expose internal model schemas directly in API responses (use DTOs).

## 5. Testing
- **Pattern**: Follow Arrange-Act-Assert (AAA).
- **Quality**: Write deterministic tests. Mock/stub external dependencies (never hit real databases/APIs in unit tests).
- **Coverage**: Include edge cases and error handling paths for all new functions.
- **Execution**: Run tests natively using the project's package manager (`pnpm run test`, `pnpm run test:unit`). Do NOT run redundant installation commands (e.g., `npm i`) before testing, and do not wrap tests in graphical launchers like `xvfb-maybe` unless explicitly required by the environment.
- **Import over copy**: Before inlining any constant or function into a test file, first check if its source module can be imported directly in the Node test environment. A module is safe to import if it has **none** of the following: `'use client'` directive, React hooks (`useState`, `useEffect`, `useRef`, etc.), JSX, CSS module imports, or Next.js-specific APIs. If safe, use `import` from the source path (vitest aliases: `helpers/`, `services/`). Only copy when the source cannot be imported. Document the reason in a comment (e.g., `// addCamera.js has React component imports — STATUS_MAP must be inlined`).

## 6. Output & Collaboration
- **Format**: Explanation first -> complete code block -> test cases. Include ALL necessary imports.
- **Communication**: Respond to the user in English. Do NOT translate project domain terms (e.g., maintain 抽查記錄表, 編輯模版 as they are).
- **Git**: Use Conventional Commits (`feat: ...`, `fix: ...`). Prefer small, composable commits for easy review.
- **Dependencies**: Justify any new dependency. Prefer the standard library or existing project libraries. Avoid heavy packages for trivial tasks.
- **Performance**: Avoid O(n²) or worse algorithms on large datasets. Prefer lazy evaluation or streaming for bulk operations. Avoid N+1 query patterns.

## 7. Forbidden Actions (Require Explicit Confirmation)
- Running destructive shell commands (`rm -rf`, `git reset --hard`, `DROP TABLE`, etc.).
- Modifying files outside of `/etc/moneytek/construction_pmis`.
- Installing global packages (`npm install -g`, `pip install --user`).
- Pushing, amending, or deleting branches/commits directly.
- Bypassing safety checks (e.g., `--no-verify`, `--force`).

## 8. Process & Behavior
- **Read before writing**: Before adding code, read exports, immediate callers, and shared utilities. "Looks orthogonal" is dangerous — if unsure why code is structured a certain way, ask.
- **Surface conflicts**: If two patterns contradict, pick one (more recent / more tested), explain why, and flag the other for cleanup. Don't blend conflicting patterns.
- **Match conventions**: Conformance over personal taste inside the codebase. If a convention seems harmful, surface it — don't fork silently.
- **Fail loud**: "Completed" is wrong if anything was skipped silently. "Tests pass" is wrong if any were skipped. Surface uncertainty — don't hide it.

## 9. Framework & Stack Conventions

### Next.js (App Router)
- Default to Server Components; add `'use client'` only when required (hooks, browser APIs, event handlers).
- Unwrap dynamic route params with `React.use(params)` — do not access `params.xxx` directly in async page components.
- Keep initial data fetching in Server Components or the service layer; avoid `useEffect` for data that can be loaded server-side.
- API route handlers live in `src/app/api/`; follow REST conventions and always return typed responses via DTOs.

### SCSS Modules
- Import mixins via `@use 'styles/scss/mixins' as m`; use `@include m.mobile` for the ≤576px breakpoint.
- Use CSS custom properties (`--var-name`) for design tokens shared across components; avoid hardcoding colors or sizes.
- No global side-effecting styles inside `.module.scss` files — keep modules fully scoped.
- Class names in `.module.scss` use `camelCase` to match JS property access (e.g., `styles.myClass`).

### Redux
- Read state exclusively via `useSelector`; never call `store.getState()` directly inside React components.
- Co-locate selectors with their slice file; do not define inline selectors inside components.
