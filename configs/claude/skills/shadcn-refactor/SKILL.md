---
name: shadcn-refactor
description: Migrate a .js/.jsx page or component to this repo's shadcn UI system — replace Bootstrap classes, styled-components, MKButton/pmisUI wrappers, and hardcoded styles with src/components/common, shadcn src/components/ui, Tailwind tokens, and centralized icons/constants. Use when asked to refactor UI to shadcn, migrate Bootstrap or styled-components, or modernize a legacy modal/page's styling.
---

# shadcn-refactor

Styling-scoped migration of a legacy page/component to this repo's shadcn system.
Preserve behaviour, layout, and user-facing strings. The ONLY non-styling change
allowed is centralizing icons/constants (a pure extract-and-import move).

## When to use

- A `.js`/`.jsx` page or component still uses Bootstrap (`row`, `col-*`,
  `form-control`, `is-invalid`, `nav-tabs`, `d-flex`, …), styled-components,
  inline hex styles, or `MKButton` / pmisUI wrappers.
- The user asks to "refactor to shadcn", migrate a modal/page, or modernize styling.

## Procedure

1. **Confirm the target.** If the file is ambiguous or has nothing to migrate, ask first.
2. **Inventory reuse before mapping.** Read `component-map.md` and pick the
   highest-priority existing component for each piece. Priority order:
   `src/components/common/` → shadcn `src/components/ui/` + Tailwind → SCSS module
   only for layout Tailwind can't express cleanly.
3. **Find a canonical sibling.** Prefer a same-folder, already-refactored file as
   the pattern to copy. `examples.md` lists repo-proven patterns (FullCategory
   modal, FieldGroup form rows, DynamicTabs).
4. **Apply the mappings** in `class-token-map.md` (Bootstrap→Tailwind, MKButton
   variant→shadcn, styled-components→FieldGroup, hardcoded colour→token).
5. **Reassign variants by semantics — do NOT 1:1 map.** One primary CTA per group;
   the rest become `outline`/`ghost`. Avoid a wall of one colour.
5b. **Reuse hooks.** For cross-cutting behaviour (element/window sizing, scroll
   detection, resize observation) prefer existing hooks in `src/hooks/` instead of
   reimplementing inline. Only add a new hook there when none fits.
6. **Centralize** SVGs → `src/lib/icons.js` (`import { ... } from '@/lib/icons'`),
   shared constants → `src/helpers/utilities/const/<file>`
   (`import { ... } from 'helpers/utilities/const/<file>'`). Extract + import only;
   never inline raw `<svg>`, never change a value or rendered output.
7. **Verify.** Run `pnpm exec eslint --fix` on every changed file. eslint passing
   does NOT prove behaviour is preserved — for context-dependent components
   (Radix Tabs/Trigger, react-hook-form) confirm provider/control wiring, and
   prefer opening the screen to confirm.

## Hard boundaries

- Default scope is styling. Do NOT change layout, text content, or behaviour.
  Removing dead/no-op style declarations is fine.
- Do NOT rewrite styling with styled-components or any CSS-in-JS.
- Do NOT touch user-facing strings or introduce i18n — that is a separate task.

## Bundled references (read on demand)

- `component-map.md` — what is reusable in `common/` and `ui/`, and how to choose.
- `class-token-map.md` — Bootstrap class, MKButton variant, and styled-components
  → shadcn / Tailwind / token tables.
- `examples.md` — before/after patterns proven in this repo.
