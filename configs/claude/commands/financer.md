---
description: Run the financer subagent — screen the core ETF allocation and candidate stocks on a fixed fundamentals framework, assess whether the Taiwan / US index level is earnings-backed, and save a dated report under ~/financer/reports/
---
Dispatch the `financer` subagent (Agent tool, `subagent_type: "financer"`, model opus) to produce a personal stock research report.

- Pass $ARGUMENTS through verbatim as the watchlist / focus: codes, Chinese names, English names and ADR names (e.g. `TSMC`) are all fine — the subagent resolves them to Taiwan codes itself. If $ARGUMENTS is empty, tell the subagent to use the core allocation in `~/financer/ref/core-allocation.md` and pick its own 3+ candidates.
- Scope keyword (default `all`, pick one): `ETF` → only 核心配置檢視; `股票` / `stock` → only 潛力股評估 / 除權息 / 法人與總經; `法人` → only the institutional-flow section; `預警` / `--warn` → signal-timing review; `大盤` / `market` → index real-vs-hollow assessment, optionally narrowed with `台股`/`tw` or `美股`/`us` (no stock codes); `all` → ETF + stocks. Every Chinese keyword has an English alias (`etf`, `stock`, `chips`, `warning`, `market`). 「與上次比較」「免責」always render. Combinable with the watchlist and flags (e.g. `2330 2454 股票`, `ETF -S`).
- Recognised flags: `--sources` (aliases `-S`, `附來源`) — appends 「附錄 A、資料來源清單」with each figure's full URL + access date (inline site+date citations are always present); `--no-chart`; a window such as `近5日` / `5d`, `本月` / `mtd`, or `20250101-today` for the institutional section.
- The subagent needs live web data (WebSearch / WebFetch). It must cite a source + date for every figure and mark anything it cannot find as「資料未提供」— never fabricate numbers. Biotech / pre-profit stocks are excluded, not force-fitted.
- **Do not name the output file.** The subagent names it by its own convention (scope + codes), saves it under `~/financer/reports/`, and adds a row to `~/financer/reports/INDEX.md`.
- Relay the report back verbatim, with the saved path; do not add buy/sell recommendations of your own.
