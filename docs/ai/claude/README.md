# Construction

> **這是架構藍圖(文件),不是設定檔本體。**
> 可部署的正式來源在 [`configs/claude/`](../../../configs/claude/)
> (agents / commands / skills / hooks / settings.json,
> 以及 `settings.local.example.json` 個人設定範本 — 實際的
> `settings.local.json` 屬個人本機檔,不進版控)。
> 部署方式:`bash install.sh claude`(或 `sudo bash install.sh claude` 部署給
> DEPLOY_USER),會部署到 `~/.claude/`,只管理 agents/commands/skills/hooks、
> settings.json 與 CLAUDE.md,覆蓋前先備份;四個目錄各留一份
> `.dotfiles-manifest`,只移除 dotfiles 自己放過的檔案,不碰 sessions、
> plugin 或同步來的 skills 等其他內容。

```
全域 ~/.claude/                          — 個人跨專案通用設定
├── CLAUDE.md                            — 個人行為規範（不綁定技術棧）
├── agents/                              — 真正跨專案的通用角色
├── commands/                            — 個人常用的通用 slash command
└── settings.json                        — 個人偏好設定

區域 <Project Path>/
├── .claude/
│   ├── agents/                          — 角色定義（各角色的知識與行為規範）
│   │   ├── pm.md                        — PM：需求轉「結構化任務」，先整理任務清單再分派給其他角色
│   │   ├── builder.md                   — 綜合開發角色（小型專案用）
│   │   ├── frontender.md                — React/Next.js、SCSS、UI 邏輯
│   │   ├── backender.md                 — API、商業邏輯、驗證
│   │   ├── databaser.md                 — Schema、migration、查詢優化
│   │   ├── devopser.md                  — CI/CD、部署、監控告警
│   │   ├── security.md                  — 資安稽核：漏洞掃描、相依套件檢查、權限控管審查
│   │   ├── codereviewer.md              — 程式品質把關 + 合併審閱（確認可合併）
│   │   └── tester.md                    — 測試案例撰寫與執行
│   │
│   ├── commands/                        — slash command（呼叫角色的快捷方式）
│   │   ├── pm.md                        — /pm
│   │   ├── builder.md                   — /builder
│   │   ├── frontender.md                — /frontender
│   │   ├── backender.md                 — /backender
│   │   ├── databaser.md                 — /databaser
│   │   ├── devopser.md                  — /devopser
│   │   ├── security.md                  — /security
│   │   ├── codereviewer.md              — /codereviewer
│   │   └── tester.md                    — /tester
│   │
│   ├── skills/                          — 可重複使用的專項能力（跨角色共用）
│   │   ├── shadcn-refactor
│   │   │   ├── SKILL.md                 -  (54 行) ← 叫用時載入:核心流程 + 邊界 + 何時用
│   │   │   ├── component-map.md         -  (57 行) ← 需要時讀:common/ + ui/ 可重用清單與優先序
│   │   │   ├── class-token-map.md       -  (69 行) ← 需要時讀:Bootstrap/MKButton/styled→shadcn 對照表
│   │   │   └── examples.md              - (100 行) ← 需要時讀:本 repo 已驗證的 before/after 範式
│   │   ├── self-review/                 — 自我修正檢查流程
│   │   ├── test-patterns/               — React 測試模式（act、renderHook、waitFor）
│   │   └── commit-convention/           — Conventional Commits 規範
│   │   （每個 skill 建議附簡短 changelog / 更新日期，避免內容過時）
│   │
│   ├── hooks/                           — 強制規則（比 CLAUDE.md 的「建議」更有約束力）
│   │   ├── pre-commit-lint.sh           — commit 前自動跑 lint
│   │   └── block-main-push.sh           — 禁止直接改 main 分支
│   │
│   ├── mcp.json                         — 專案使用的 MCP server 清單（Jira、Slack 等外部工具串接）
│   ├── settings.json                    — 團隊共用設定（進版控）
│   └── settings.local.json              — 個人本機設定（gitignore，排除版控）
│
├── workflow.md                          — 角色呼叫順序：
│                                            /pm → 分派角色(/frontender /backender…) → /tester → /security → /codereviewer → 合併
│
└── CLAUDE.md                            — 專案總覽規範
```