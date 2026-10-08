# Copilot instructions — dotfiles

The rules for this repository live in `.claude/CLAUDE.md` (project section P1–P4); they
apply to every assistant. The short version:

- **One library, two consumers.** `configs/alias/` is the runtime library (deployed to
  `/etc/profile.d/.alias`); the deploy tool (`install.sh`, `lib/`, `modules/`) sources
  its repo copy. Reuse what it has — platform globals (`OS_FAMILY`, `PKG_MGR`, `SUDO`,
  paths), `log_*`, `confirm` / `ask` / `radioselect` / `multiselect`, `pkg_install` —
  never re-implement it.
- **Commands: arguments first, menus as the fallback.** Everything can be passed as
  arguments; a menu opens only when input is missing and `ui_tty` succeeds; without a
  terminal, fail with usage. `-h` usage, `-n` dry run, `-y` yes; `confirm` before
  anything destructive. No hand-rolled `read -p` prompts, no literal `sudo` (`$SUDO`).
- **Modules write through `lib/deploy.sh` and run commands through `df_run`**, so
  `--dry-run` and `--root` stay truthful; validate files before installing them;
  a second run must change nothing.
- **Both families**: Ubuntu 20.04+ / Debian 11+ and RHEL / Rocky / Alma 9+. Branch on
  `OS_FAMILY` / `OS_ID`; distro package names go in `PKG_NAME_MAP`.
- Bash naming: `snake_case` functions with a short alias (`git_drop_stashes` / `gds`),
  `UPPER_SNAKE_CASE` globals as `${VAR:-default}`; shdoc-style `# @name` headers.
- Verify with `bash tests/run.sh` (lint + smoke + deploy) before committing.
