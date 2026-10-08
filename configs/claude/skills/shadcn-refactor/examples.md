# Repo-proven patterns

Copy these shapes. They are taken from already-migrated files in this repo —
prefer reading the live file for the latest form.

## Canonical reference files

- `src/components/modals/newTableData/FullCategory.js` — fully migrated modal:
  shadcn `Input` + `aria-invalid`, `Button type='submit'` + `SpinnerSmall`,
  `Separator`, `FieldRow` rows. Use as the template for modal refactors.
- `src/components/modals/newProblemReport.js` — Dialog-based modal, shadcn
  `Spinner` in submit button, `aria-invalid` + destructive error text.
- `src/components/molecular/LabelInputRow.js` — the `FieldGroup` pattern that
  replaced the styled-components InputGroup family.

## Form row (label + input + error)

```jsx
<LabelInputRow_48
    error_msg={errors.name?.message}
    input={
        <Input
            aria-invalid={errors.name ? true : undefined}
            id='name'
            type='text'
            {...register('name')}
        />
    }
    label_id='name'
    labelName='報表名稱'
/>
```

## Read-only label/value rows (was `row`/`col-4`/`col-8`)

```jsx
<Row48 first={`${projectType}模板：`} second={template_data.name} />
<Row48 first='模板種類：' second={template_data.category} />
```

## Submit button (was `MKButton variant='primary'`)

```jsx
<Separator className='my-3' />
<div className={styles.button_container}>
    <Button disabled={formState.isSubmitting} type='submit'>
        {formState.isSubmitting && <SpinnerSmall />}
        新增
    </Button>
</div>
```

## Button group — reassign by semantics

A group of peer actions becomes `outline`; do not carry over `primary`/`success`/`info`:

```jsx
<MKButtonList>
    <Button variant='outline' onClick={...}>編輯實際工程進度</Button>
    <Button variant='outline' onClick={...}>編輯預定工程進度</Button>
    <Button variant='outline' onClick={...}>背景圖檔編輯</Button>
</MKButtonList>
```

## Tabs (was `nav nav-tabs`)

```jsx
<DynamicTabs card={false} className='mt-3' value={activeTab} onValueChange={setActiveTab}>
    <DynamicTabsHeader card={false}>
        <DynamicTabsTrigger value={overallProgress}>{activeTabs_CH.overallProgress}</DynamicTabsTrigger>
        <DynamicTabsTrigger disabled={!pdfUrl} value={subProgress}>{activeTabs_CH.subProgress}</DynamicTabsTrigger>
    </DynamicTabsHeader>
    {/* panels rendered conditionally by activeTab */}
</DynamicTabs>
```

## Bordered card panel (was inline hex border/radius)

```jsx
<div className='bg-card flex flex-col gap-2 mt-1 rounded-lg border-2 border-border p-2'>
    ...
</div>
```

## FieldGroup (addon label + control, replaces styled InputGroup)

```jsx
<div style={{ width, padding }}>
    <div className={cn('flex items-stretch overflow-hidden rounded-lg border',
        error ? 'border-destructive' : 'border-input')}>
        {label && (
            <span className='flex shrink-0 items-center border-r border-input bg-muted px-2.5 text-muted-foreground'>
                {label}
            </span>
        )}
        {children /* shadcn Input with: className='flex-1 rounded-none border-0 focus-visible:ring-0' */}
    </div>
    {error && <p className='mt-1 text-xs text-destructive'>{error}</p>}
</div>
```
