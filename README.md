# dotfiles

Linux environment automation for Ubuntu and the RHEL family: one shell library every
user gets, and a deploy tool that sets a host up — packages, maintenance jobs, sudo,
databases, Docker, Node, network, HTTPS — module by module.

```
configs/alias/  ── the runtime library ──►  /etc/profile.d/.alias  (every interactive bash,
      ▲                                                             cron scripts too)
      │ sourced from the repo
install.sh ─► lib/core.sh + lib/deploy.sh ─► modules/<name>/main.sh ─► the host
```

One implementation of everything shared: the deploy tool sources the repo copy of the
same library users run, so platform detection, logging, menus and package handling exist
once.

## Supported systems

| Family | Releases | Package manager | System bashrc |
|---|---|---|---|
| debian | Ubuntu 20.04+, Debian 11+ | apt | `/etc/bash.bashrc` |
| rhel | RHEL 9+, Rocky 9+, Alma 9+ | dnf (+ EPEL/CRB) | `/etc/bashrc` |

Detected from `/etc/os-release`. Deploys refuse anything else unless `DF_FORCE=1`.
CI runs the test suites in Ubuntu 20.04, 22.04 and 24.04, Rocky 9 and RHEL 9 (UBI) containers.

## Quick start

```bash
git clone https://github.com/ragnarokmin0714/dotfiles.git ~/dotfiles && cd ~/dotfiles
bash install.sh --list                    # what there is
bash install.sh -n packages shell maint   # what it would do -- changes nothing, no root needed
sudo bash install.sh packages shell maint # do it
sudo bash install.sh                      # or pick modules from a menu
```

After `shell`, every new interactive bash on the host has the library, and
`dotfiles <args>` runs this installer from anywhere (`dotfiles shell` after editing
`configs/alias/`).

## install.sh

```
install.sh [options] [module...]     no module: pick from a menu
  -l, --list       list modules
  -a, --all        every module not marked [manual]
  -n, --dry-run    show every change, make none
  -y, --yes        answer yes to every question
      --root DIR   sandbox: write files under DIR, run no commands
```

- Modules run in their fixed order, whatever order you name them in; the first failure
  stops the run.
- Every run is logged: `/var/log/dotfiles/install/` as root, otherwise
  `~/.local/state/dotfiles/install/`.
- Every file a run replaces is backed up first, under `/var/backups/dotfiles/<run>/`.
- Re-running is safe: a second run reports everything `unchanged`.
- Try the RHEL code paths on an Ubuntu box:
  `OS_FAMILY=rhel OS_ID=rocky OS_VERSION=9.4 bash install.sh -n --all`

## Modules

| Module | What it does | `--all` |
|---|---|---|
| `packages` | build tools, certificates, archivers, and the CLI toolkit (`SYS_TOOLKIT`: git, curl, jq, htop, lnav); EPEL + CRB on the RHEL family | ✔ |
| `shell` | the library → `/etc/profile.d/.alias`; a managed hook block in the system bashrc; git defaults in `/etc/gitconfig` | ✔ |
| `maint` | `/usr/local/sbin/{sys-maint,ntp-sync}.sh`, `/etc/cron.d/dotfiles-maint`, `/etc/logrotate.d/dotfiles`, logs in `/var/log/dotfiles` | ✔ |
| `claude` | Claude Code config → `~/.claude` of the deploy user (only what dotfiles put there is ever removed) | ✔ |
| `docker` | Docker CE + compose/buildx from Docker's repo; deploy user joins `docker` | ✔ |
| `node` | nvm + Node (LTS) + pnpm for the deploy user | ✔ |
| `python` | python3, pip, venv | ✔ |
| `go` | Go from go.dev, SHA-256 verified | ✔ |
| `sudo` | NOPASSWD rules for the deploy user — includes root-equivalent grants, read the template | manual |
| `postgres` / `mysql` / `redis` | servers, plus `DB_NAME` / `DB_USER` (password from `config.local.sh`) | manual |
| `network` / `firewall` / `https` | static IP + DNS; declarative firewall (22 required); nginx with a self-signed cert | manual |
| `iso` | experimental: repack a Debian-installer ISO with preseed | manual |

## The shell library

Each module of `configs/alias/` covers one area. Commands take their input as arguments
and open a menu only when something is missing and there is a terminal. Destructive steps
ask first (`-y` answers yes), and `-n` previews. `<command> -h` prints usage.

| Module | Commands (aliases) |
|---|---|
| `.bash_env` | platform globals (`OS_FAMILY`, `PKG_MGR`, `SUDO`, paths, `GIT_*`, `SYS_TOOLKIT`), `log_ok/err/warn/info/step/head/banner`, `path_add` |
| `.bash_ui` | `radioselect`, `multiselect`, `confirm`, `ask`, `ui_tty` — every question goes through these |
| `.bash_functions` | `dotfiles`, `sys_update` (`sup`), `sys_maintain` (`sys-maint`), `ntp-sync/-status/-fix`, `tz`, `find_path` (`fp`), `free_mem` (`fm`), `run_project` (`run-prj`), `stop_dev`, `rs`, `lh*`, `svc-*` |
| `.bash_pkg` | `pkg_installed` (`pi`), `pkg_ensure` (`pe`), `pkg_remove` (`prm`), `pkg_install`, `pkg_enable_epel`, `sys_toolkit` (`toolkit`), `pkg_unused` (`pun`), `ensure_shfmt` |
| `.bash_disk` | `disk_status` (`ds`), `disk_usage_top` (`dut`), `clean_up_disk` (`cud`), `clean_home_caches` (`chc`), `disk_grow` (`dg`) |
| `.bash_git` | `gfm`, `gswp`, `gcr`, `gpcb`, `gcmb`, `gds`, `grd`, `gfl`, `amend`, `gpm`, `safe-push` |
| `.bash_prompt` | the `[user(group)@host:ip dir (branch hash status)]$` prompt |
| `.bash_nginx`, `.bash_mongo`, `.bash_nvm` | `ngs`/`ngtr`/`ngl`; `mdb*` (configured in `.bash_local`); `nvm-i`/`nvm-uni`/`nvm-up` |

## Configuration

| Where | What | Committed |
|---|---|---|
| `config.sh` | deploy settings with safe defaults (ports, versions, DB names...) | yes |
| `config.local.sh` | this host's settings and secrets, sourced last — start from `config.local.example.sh` | no |
| `/etc/profile.d/.alias/.bash_local` | per-host library settings (project paths, extra aliases), loaded before the modules; never overwritten by a deploy — see `configs/alias/.bash_local.example` | no |

Any `config.sh` value can also be overridden for one run from the environment:
`NODE_VERSION=20 sudo -E bash install.sh node`.

## Layout

```
install.sh                  entry point: menu / module names / -n / --root / --all
config.sh                   deploy settings (config.local.sh overrides, gitignored)
lib/core.sh                 bootstrap: strict mode, the library, settings, die, df_run
lib/deploy.sh               df_install, df_install_dir, df_block, df_render, validators
modules/<name>/main.sh      one module each; header: @desc, @order, @manual
configs/alias/              the runtime library        -> /etc/profile.d/.alias
configs/sbin/               maintenance scripts         -> /usr/local/sbin
configs/cron.d/             schedule                    -> /etc/cron.d
configs/logrotate.d/        log rotation                -> /etc/logrotate.d
configs/sudoers.d/          sudoers template            -> /etc/sudoers.d
configs/gitconfig           git defaults                -> /etc/gitconfig (managed block)
configs/claude/             Claude Code config          -> ~/.claude
tests/                      lint.sh, smoke.sh, deploy.sh; run.sh runs them all
```

## Extending

- **A command**: add it to the `configs/alias/` module for its area, then follow the
  convention in `.bash_ui`'s header:
  - arguments and flags first, with `-h`;
  - `radioselect`/`multiselect`/`ask` only as the fallback when input is missing and
    there is a terminal;
  - `confirm` before anything destructive;
  - `$SUDO` for root.
  - Option letters are listed in `.bash_aliases`.
- **A module**: create `modules/<name>/main.sh` with `# @desc` and `# @order`, source
  `lib/core.sh`, and call `df_module_start`.
  - Write files only through `lib/deploy.sh`, and run commands through `df_run`, so
    `-n` and `--root` stay truthful.
  - It shows up in the menu and in `--list` by itself.

`.claude/CLAUDE.md` holds the full rules.

## Tests

```bash
bash tests/run.sh      # lint + smoke + deploy, no root needed
```

- `lint.sh`: `bash -n`, shellcheck, and policy checks for the conventions above (prompts
  only through `.bash_ui`, `$SUDO` not `sudo`, module headers).
- `smoke.sh`: the library in a clean strict-mode shell, with no terminal, on both families.
- `deploy.sh`: real deploys into `--root` sandboxes. It covers:
  - modes and validators;
  - a second run changing nothing;
  - host files kept, dropped files removed;
  - refusal of broken input;
  - dry runs of every module on Ubuntu 20.04/22.04, Rocky 9 and RHEL 9.
