# docs/refs/.alias — Archived v1 Alias Modules

This directory archives the **first-generation** `.bash_*` alias modules,
retired on 2026-07-10 when the second generation was promoted to
`configs/alias/`.

**These files are NOT deployed.** The canonical, deployed source is
`configs/alias/`.

## Generation history

| Generation | Location | Status |
|------------|----------|--------|
| v1 (this directory) | `docs/refs/.alias/` | Archived — plain `echo` output, no log framework, 4 modules |
| v2 (current) | `configs/alias/` | Canonical — `log_*` framework in `.bash_env`, adds `.bash_pkg` (package toolkit) and `.bash_nginx`, 6 modules |

v1 features that were ported into v2 before retirement (nothing of value
was lost):

- apt branch of `clean_up_disk` (cache clean, autoremove, old-kernel purge)
  with npm/pnpm presence guards
- Distro-aware `ntp_status` / `ntp_fix` (chronyd vs systemd-timesyncd)

## Purpose

- Side-by-side comparison point when reviewing v2 changes
- Fallback reference if a v2 regression needs the original behavior

## Do not edit here expecting changes to take effect

Any updates must be made to `configs/alias/` and deployed via:

```bash
sudo bash system/aliases.sh
```

## Files (v1, archived)

| File | Description |
|------|-------------|
| `.bash_aliases` | Entry point — sources the other three files via `_ALIAS_DIR` |
| `.bash_env` | ANSI STYLE map, `styled()`, `git_prompt()`, `build_ps1()` |
| `.bash_functions` | System utility functions incl. STYLE-based `pkg_installed/ensure/remove` |
| `.bash_git` | Git aliases and interactive branch functions |
