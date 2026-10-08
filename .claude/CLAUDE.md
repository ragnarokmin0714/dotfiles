# CLAUDE.md — 12-rule template

These rules apply to every task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

## Rule 1 — Think Before Coding
State assumptions explicitly. If uncertain, ask rather than guess.
Present multiple interpretations when ambiguity exists.
Push back when a simpler approach exists.
Stop when confused. Name what's unclear.

## Rule 2 — Simplicity First
Minimum code that solves the problem. Nothing speculative.
No features beyond what was asked. No abstractions for single-use code.
Test: would a senior engineer say this is overcomplicated? If yes, simplify.

## Rule 3 — Surgical Changes
Touch only what you must. Clean up only your own mess.
Don't "improve" adjacent code, comments, or formatting.
Don't refactor what isn't broken. Match existing style.

## Rule 4 — Goal-Driven Execution
Define success criteria. Loop until verified.
Don't follow steps. Define success and iterate.
Strong success criteria let you loop independently.

## Rule 5 — Use the model only for judgment calls
Use me for: classification, drafting, summarization, extraction.
Do NOT use me for: routing, retries, deterministic transforms.
If code can answer, code answers.

## Rule 6 — Token budgets are not advisory
Per-task: 4,000 tokens. Per-session: 30,000 tokens.
If approaching budget, summarize and start fresh.
Surface the breach. Do not silently overrun.

## Rule 7 — Surface conflicts, don't average them
If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup.
Don't blend conflicting patterns.

## Rule 8 — Read before you write
Before adding code, read exports, immediate callers, shared utilities.
"Looks orthogonal" is dangerous. If unsure why code is structured a way, ask.

## Rule 9 — Tests verify intent, not just behavior
Tests must encode WHY behavior matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

## Rule 10 — Checkpoint after every significant step
Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back.
If you lose track, stop and restate.

## Rule 11 — Match the codebase's conventions, even if you disagree
Conformance > taste inside the codebase.
If you genuinely think a convention is harmful, surface it. Don't fork silently.

## Rule 12 — Fail loud
"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

---

# Project-specific rules (this repo)

These extend the template above with boundaries specific to this dotfiles
repo. When the template gets upgraded, keep this section. Where code can check
a rule, tests/lint.sh does -- run `bash tests/run.sh` before every commit.

## P1 — One library, two consumers; reuse it, never re-implement it
- `configs/alias/` is the runtime library: deployed to /etc/profile.d/.alias for
  every interactive bash and sourced by the cron scripts. Everything reusable
  lives here -- platform globals (.bash_env), menus and prompts (.bash_ui),
  packages (.bash_pkg) -- one domain per `.bash_<area>` module.
- The deploy tool (`install.sh`, `lib/core.sh`, `lib/deploy.sh`,
  `modules/*/main.sh`) sources the REPO copy of that library. It adds only what
  deploying needs: `die`, `df_run`, the `df_*` file primitives.
- Before writing a helper, grep configs/alias. Same capability twice anywhere in
  the repo is a defect (Rule 8 applied to shell).
- The library never exits and never calls `set` (it runs inside users' shells),
  and every module file must source cleanly under `set -euo pipefail` (its last
  statement must not return non-zero). `die` exists only in lib/core.sh.
- Globals over literals: platform facts, paths and tunables are `${VAR:-default}`
  in .bash_env (or config.sh for deploy settings); host-specific values go in
  .bash_local / config.local.sh, never in the repo.
- Tests source neither layer: they drive the code the way its users do.

## P2 — Commands take arguments first; menus are the fallback
For every user-facing function in configs/alias:
- Everything it needs can be passed as arguments or flags, so it works from
  scripts, cron and `ssh host cmd`. `-h|--help` prints usage.
- Only when required input is missing AND `ui_tty` succeeds does it open a menu:
  `radioselect` (one), `multiselect` (several), `ask` (free text). With no
  terminal it fails with usage -- it never waits on input that cannot come.
- Destructive steps go through `confirm`; `-y|--yes` answers yes, `-n|--dry-run`
  shows what would happen and changes nothing.
- Never hand-roll `read -p` prompts or numbered menus outside .bash_ui (lint
  checks). Root commands use `$SUDO`, never a literal `sudo` (lint checks).
- Option letters keep one meaning across modules: check the table in
  .bash_aliases before adding one.
- Naming: `snake_case` function + kebab/short alias (`git_drop_stashes` / `gds`),
  shdoc `# @name` header with @param and @example.

## P3 — Deploy modules: declared, dry-runnable, idempotent
- `modules/<name>/main.sh`, header `# @desc`, `# @order` (and `# @manual` when it
  must not run under --all); sources lib/core.sh, calls `df_module_start`, and
  `df_need_root` when it needs root. Discovery is automatic (lint checks).
- Files only through lib/deploy.sh (`df_install`, `df_install_dir`, `df_block`,
  `df_render_install`, `df_write`, `df_mkdir`) -- never `cp`/`cat >` into the
  system. Commands only through `df_run`, `df_as_user`, or runtime helpers given
  `"${DF_N[@]}"`. That is what keeps `-n` and `--root` truthful.
- Validate before installing (`-v df_check_*`). Directories dotfiles owns prune
  by glob (`-p`); directories shared with other tools use a manifest (`-M`).
  Files and blocks other tools also edit get a managed block (`df_block`), and
  any other edit to such a file comes after `df_block_check`.
- A second run changes nothing (tests/deploy.sh checks).
- Supported: Ubuntu 20.04+ / Debian 11+, RHEL / Rocky / Alma 9+. Branch on
  `OS_FAMILY` (and `OS_ID` where RHEL differs from its rebuilds); package names
  that differ go in `PKG_NAME_MAP`, not in `case` arms.

## P4 — Verification
- `bash tests/run.sh`: lint (syntax, shellcheck, policy), smoke (the library,
  strict and terminal-less, both families), deploy (sandboxed deploys and dry
  runs of every module on both families). All three must pass.
- CI (.github/workflows/ci.yml) repeats smoke and deploy in Ubuntu 20.04 /
  22.04 / 24.04, Rocky 9 and RHEL 9 (UBI) containers. Paths that only a real
  host can show (services starting, packages installing) are verified on a host
  -- say so when a change was not.
