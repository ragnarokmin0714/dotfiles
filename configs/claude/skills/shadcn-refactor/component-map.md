# Component map — what to reuse

Pick in this priority order. Only fall back to the next tier when no fit exists.

## Tier 1 — `src/components/common/` (barrel: `from 'components/common'`)

Project wrappers around shadcn; prefer these first.

| Export | Use for |
| --- | --- |
| `FieldRow`, `FieldCol` | label + input layouts (from `field-layout`) |
| `Combobox` | searchable single-select with free text |
| `SearchInput` | search box |
| `InputGroup` | input with leading/trailing addon |
| `DropdownField` | RHF-friendly select (bridge via `control` or `onChange`) |
| `NativeSelectField` | native `<select>` styled to shadcn |
| `ProgressBar`, `ProgressBarInline` | progress bars |
| `RadioField` | radio groups |
| `SelectField` | Radix select field |
| `SortButton` | sortable column header button |
| `SwitchField` | toggle |
| `DataTable` | tabular data |
| `FileTree` | file/folder tree |

Not in the barrel — import directly:

| Component | Path |
| --- | --- |
| `DynamicTabs`, `DynamicTabsHeader`, `DynamicTabsTrigger` | `components/common/dynamic-tabs` |

## Tier 2 — shadcn primitives `src/components/ui/` (`from 'components/ui/<name>'`)

Use when no `common/` wrapper fits. Available: accordion, autocomplete, avatar,
badge, button, button-group, card, collapsible, combobox, context-menu,
date-picker, dialog, dropdown-menu, field, info-popover, input-group, input,
label, native-select, navigation-menu, progress, radio-group, select, separator,
skeleton, slider, sonner, switch, table, tabs, textarea.

Common picks:
- `Button` (`components/ui/button`) — replaces `MKButton`, Bootstrap `btn`.
- `Input` (`components/ui/input`) — replaces `<input className='form-control'>`.
- `Separator` (`components/ui/separator`) — replaces `<hr />`.
- `Textarea`, `Label`, `Card`, `Dialog`.

## Tier 3 — shared form molecules `src/components/molecular/LabelInputRow`

Already shadcn-based. Reuse instead of rebuilding label/value rows:
- `LabelInputRow_48` — label(4) / input(8) grid row with built-in error text.
- `Row48`, `Row84`, `Row102` — read-only 4/8, 8/4, 10/2 display rows.
- `LabelInputbox`, `LabelSelectbox`, `LabelInputFile`, `LabelInputNumber` — addon-style fields.
- `SpinnerSmall` (`components/molecular/Spinner`) — inline button spinner used across modals.

## Tier 4 — SCSS module

Only for layout Tailwind genuinely cannot express. Keep classes camelCase and
scoped. Shared modal classes like `Modal.module.css` `button_container` are reused
across many modals — keep using the shared class, do not inline one-offs.
