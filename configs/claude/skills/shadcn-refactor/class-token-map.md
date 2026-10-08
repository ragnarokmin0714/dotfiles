# Class / variant / token map

These are starting points. **Semantics override the table** — reassign button
variants by role, not by a fixed 1:1 mapping.

## Bootstrap class → Tailwind / shadcn

| Bootstrap | Replace with |
| --- | --- |
| `row` | `grid grid-cols-12 gap-x-3` (or `flex` when not a 12-col grid) |
| `col-4` / `col-8` / `col-N` | `col-span-4` / `col-span-8` / `col-span-N` |
| `d-flex` | `flex` |
| `flex-column` | `flex-col` |
| `align-items-center` | `items-center` |
| `justify-content-end` | `justify-end` |
| `flex-grow-1` | `grow` |
| `text-nowrap` | `whitespace-nowrap` |
| `me-2` / `ms-2` | `mr-2` / `ml-2` |
| `nav nav-tabs` / `nav-item` / `nav-link active` | `DynamicTabs` / `DynamicTabsHeader` / `DynamicTabsTrigger` (`value`-driven) |
| `<input className='form-control'>` | shadcn `<Input>` |
| `<select className='form-control'>` | `NativeSelectField` or `DropdownField` |
| `is-invalid` (on field) | `aria-invalid={err ? true : undefined}` on the shadcn control |
| `<div className='invalid-feedback'>` | `<p className='mt-1 text-xs text-destructive'>` |
| `<hr />` | `<Separator className='my-2' />` (token-aware; `<hr>` is not dark-mode aware) |
| `btn` / `btn-*` | shadcn `<Button variant=...>` |
| `card` | `bg-card rounded-lg border border-border …` or shadcn `Card` |

## MKButton variant → shadcn variant (semantics override)

`MKButton` already wraps shadcn `Button` via this map. When replacing it with a
direct `<Button>`, start from the map then **reassign by role**.

| MKButton variant | shadcn variant |
| --- | --- |
| `info`, `success`, `primary` | `default` |
| `warning`, `dark` | `outline` |
| `danger`, `rose` | `destructive` |
| `secondary`, `bookspine` | `secondary` |
| `light` | `ghost` |

Role rule: exactly one primary CTA (`default`) per button group; secondary
actions become `outline`/`ghost`. A row of edit buttons should NOT all be
`default` even if their old variants differed.

Note: `MKButton` defaults to `type='button'`. Inside a `<form onSubmit>`, the
submit button must be explicit `type='submit'` (native `<button>` defaulted to
submit, so legacy markup relied on it).

## Hardcoded style → token

| Hardcoded | Token |
| --- | --- |
| `backgroundColor:'#fff'` / white | `bg-card` (surface) or `bg-background` |
| `color:'#333'` etc. | `text-foreground` / `text-muted-foreground` |
| `border:'2px solid #696969'` | `border-2 border-border` |
| `borderRadius:'10px'` | `rounded-lg` |
| `border:'1px solid var(--border)'` | `border border-border` |
| muted addon bg (`#e9ecef`) | `bg-muted text-muted-foreground` |

### Keep inline `style` when the value is computed at runtime

The hardcoded→token rule targets **static design values** (colour, border,
radius, spacing, font-size). It does NOT apply to inline styles whose value
comes from JS at runtime — keep those inline; Tailwind cannot express them.

| Keep inline (runtime value) | Convert to token/Tailwind (static design value) |
| --- | --- |
| `style={{ top: `${pos.top}px` }}` (from `getBoundingClientRect`) | `background:'#fffbe6'` → `bg-amber-50` |
| progress bar width from state/props | `padding:'6px 16px'` → `px-4 py-1.5` |
| any measured/calculated dimension | `display:'flex'` → `flex` |

Rule of thumb: value from a variable/measurement → inline is correct; value is
a design token or a static literal → use Tailwind / CSS var.

## styled-components → shadcn

Do NOT keep or add styled-components. Replace the LabelInputRow-style families:

| styled component | Replace with |
| --- | --- |
| `InputGroup` + `InputLabel` + `InputText`/`InputSelect`/`InputFile` | `FieldGroup` wrapper + shadcn `Input` / native `select` with flat classes |
| styled `Button` + `ArrowIcon` + `NumberInput` | shadcn `ButtonGroup` + `Button` + `Input type='number'` |

See `examples.md` for the FieldGroup shape.
