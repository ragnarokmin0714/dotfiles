---
description: Summarize staged changes as a concise Traditional Chinese bullet work log
---
Output a concise work log written in **Traditional Chinese** for the changes described below.

Pick the source by `$ARGUMENTS`:

- **No argument (default):** review the current staged changes (`git diff --cached`).
- **`today`:** review today's commits by the current author, excluding merges
  (`git log --since="<today> 00:00" --until="<today> 23:59" --no-merges --author="$(git config user.name)"`).
  Resolve `<today>` from the system date. Inspect each commit's diff for the detail; group the
  whole day together (do not repeat a file across commits — merge its edits into one entry).
- **A date (`YYYY-MM-DD`):** same as `today` but for that date.

Format:

- **Terse bullet list** (`- ` prefix), one change per bullet — never prose paragraphs. Drop filler words; keep each bullet scannable.
- **Group by file.** Bold the file's base name as the bullet lead, then list what changed under it. Merge trivial edits into one bullet.
- Describe *what changed* at a glance (the log is for skimming later), not *why* — reserve rationale for the commit message.
- Keep project domain terms as-is (e.g. 抽查記錄表, 編輯模版); do not translate them.

Output the work log only — no commit message, no branch name, no extra explanation. If the selected source has no changes (no staged changes, or no commits in the range), inform the user.

Examples:

- `/worklog` — 維持原樣,總結目前 staged 變更。
- `/worklog today` — 總結今天你本人的 commit(排除 merge),整日彙整、同檔案跨 commit 合併成一筆。
- `/worklog 2026-07-01` — 指定日期,行為同 `today`。
