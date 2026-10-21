---
description: Summarize today's commits (or a given date / staged changes) as a concise Traditional Chinese bullet work log
---
Output a concise work log written in **Traditional Chinese** for the changes described below.

Pick the source by `$ARGUMENTS`:

- **No argument (default) / `today`:** review today's commits by the current author, excluding merges
  (`git log --all --since="<today> 00:00" --until="<today> 23:59" --no-merges --author="$(git config user.name)"`).
  **`--all` is mandatory, not a nicety.** This repo commits on short-lived `fix/*` / `feat/*` branches and
  switches back to `main` afterwards, so those commits are unreachable from HEAD — a plain `git log` silently
  returns nothing and a full day of work looks like an idle day.
  Resolve `<today>` from the system date. Inspect each commit's diff for the detail; group the
  whole day together (do not repeat a file across commits — merge its edits into one entry).
  `--all` can surface the same change twice (the branch commit plus its squash / cherry-pick on `main`) —
  keep one entry per change.
- **A date (`YYYY-MM-DD`):** same as `today` but for that date.
- **`staged`:** review the current staged changes (`git diff --cached`) instead of any commit range.

Format:

- **以 markdown 輸出**:標題固定為 `# TODO-Report-<YYYYMMDD>`(H1、日期不加分隔符,如 `# TODO-Report-20260728`),下一行**緊接** bullet 清單,標題與第一則 bullet 之間**不空行**;檔名、函式名、常數名等程式碼識別字**一律以純文字呈現,不要加反引號**(僅標題與 bullet 前綴使用 markdown 語法)。整份日誌**包在一個 ```markdown fenced code block 裡**輸出,讓原始 markdown 可直接複製貼進文件。
  - 日期取**該次查詢的對象日**:`today` 與指定日期用該日;`staged` 尚未提交、無 commit 日期,用系統當日。
- **Terse bullet list** (`- ` prefix), one change per bullet — never prose paragraphs. Drop filler words; keep each bullet scannable.
- **每則 bullet 一律為:** `- <動詞> <元件/頁面> — <一句話說明>`
- **動詞是封閉集合**,只能用下表的詞,不得自創同義詞(同一個動作每次都用同一個字,日誌才掃得動):

  | 動詞 | 對應 commit type | 用於 |
  | --- | --- | --- |
  | 新增 | feat | 新功能、新檔案 |
  | 修正 | fix | 修 bug |
  | 重構 | refactor | 不改行為的內部調整;寫「改為什麼」,不可寫成「修正…問題」 |
  | 移除 | remove / chore | 刪功能、刪檔 |
  | 調整 | style / chore | 樣式、設定、格式、文案 |
  | 測試 | test | 測試相關 |
  | 文件 | docs | 文件、註解 |
  | 標記 | — | 當天發現但未修的缺陷(新增的 FIXME / TODO / HACK) |

- **元件用產品上的名字**(如 問題討論區列表、暱稱設定彈窗),不要用檔名——檔名對日後回顧沒有意義。需要定位時才在句尾補上檔名。
- 一個檔案若同時有多種動作(例如既重構又標記缺陷),拆成多則 bullet,不要為了合併而模糊動詞。
- Describe *what changed* at a glance (the log is for skimming later), not *why* — reserve rationale for the commit message.
- Keep project domain terms as-is (e.g. 抽查記錄表, 編輯模版); do not translate them.

Output the work log only — no commit message, no branch name, no extra explanation.

**Never report "no changes" straight from one empty `git log` — an empty result is far more often a wrong query
than an idle day.** Before reporting it, corroborate with:

```
git log --all --no-merges --author="$(git config user.name)" --format='%h %ad %s' --date=short -5
```

This lists the author's latest commits regardless of date. If it shows activity on the requested date, the
original query was wrong (usually a missing `--all`) — fix it and produce the log. Only report "no changes" when
this also comes up empty for that date, and state which date the author's latest commit actually landed on so
the claim is checkable.

Examples:

- `/worklog` — 總結今天你本人的 commit(排除 merge),整日彙整、同檔案跨 commit 合併成一筆(同 `/worklog today`)。
- `/worklog 2026-07-01` — 指定日期,行為同 `today`。
- `/worklog staged` — 改看目前 staged 變更(尚未 commit 時用)。
