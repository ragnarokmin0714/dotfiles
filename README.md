# dotfiles

> Personal Linux environment automation — deploy network, databases, project tooling, shell config, and build custom ISOs with a single command.

---

## Distro Support

| Module | Ubuntu / Debian | Rocky Linux / RHEL |
|---|---|---|
| System — packages | ✅ apt | ✅ dnf + EPEL |
| System — firewall | ✅ ufw | ✅ firewalld |
| Network — static IP | ✅ Netplan | ✅ nmcli |
| Network — DNS | ✅ systemd-resolved | ✅ NetworkManager |
| Network — firewall | ✅ ufw | ✅ firewalld |
| DB — PostgreSQL | ✅ PGDG apt | ✅ PGDG dnf |
| DB — MySQL | ✅ apt + debconf | ✅ dnf + temp-pass |
| DB — Redis | ✅ redis.io apt | ✅ EPEL |
| Project — Docker | ✅ Docker apt | ✅ Docker dnf (centos) |
| Project — Go | ✅ official tarball | ✅ official tarball |
| Project — Python | ✅ apt | ✅ dnf |
| ISO build | ✅ preseed | ⚠️ xorriso only (no kickstart) |
| Shell aliases | ✅ | ✅ |

> **Distro detection** is automatic via `lib/env.sh` (`$DISTRO_FAMILY`: `debian` or `rhel`).

---

## Table of Contents

- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Menu Options](#menu-options)
- [Project Structure](#project-structure)
- [Module Reference](#module-reference)
  - [System](#system-module)
  - [Network](#network-module)
  - [Database](#database-module)
  - [Project Environment](#project-environment-module)
  - [ISO Build](#iso-build-module)
- [Logging](#logging)
- [Adding a New Module](#adding-a-new-module)

---

## Requirements

| Requirement | Notes |
|---|---|
| OS | Ubuntu 20.04+ / Debian 11+ **or** Rocky Linux 8+ / RHEL 8+ (amd64 or arm64) |
| Shell | `bash` 4.0+ |
| Privileges | Most modules require `sudo` / root |
| Network | Internet access required for package downloads |

---

## Quick Start

```bash
# 1. Clone this repository
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Edit global configuration (REQUIRED before first run)
vim lib/env.sh

# 3. Run the interactive menu
sudo bash install.sh
```

---

## Configuration

All global variables are centralized in **`lib/env.sh`**. Edit this file before running any module.

Key settings to review:

```bash
# Network
NETWORK_INTERFACE="eth0"     # Run `ip a` to find your interface name
STATIC_IP="192.168.1.100"    # Leave empty to skip static IP setup
GATEWAY="192.168.1.1"

# Database
DB_ROOT_PASSWORD="changeme"  # ← Change this
DB_USER="appuser"
DB_PASSWORD="changeme"       # ← Change this
DB_NAME="appdb"

# Node.js
NODE_VERSION="20"
PNPM_VERSION="10"

# ISO
ISO_SOURCE="/path/to/ubuntu.iso"
ISO_OUTPUT_DIR="$HOME/iso-build"
```

> **Security**: Never commit real passwords to version control. Consider using environment variables or a secrets manager for sensitive values.

---

## Usage

### Interactive menu (recommended)

```bash
sudo bash install.sh
```

Displays a numbered menu. Enter a number to run the corresponding module.

### Run a specific module directly

```bash
sudo bash install.sh --module system
sudo bash install.sh --module network
sudo bash install.sh --module db
sudo bash install.sh --module project
sudo bash install.sh --module iso
```

### Run all modules sequentially

```bash
sudo bash install.sh --all
```

Runs modules in this order: `system` → `aliases` → `network` → `db` → `project`.
(ISO is excluded from `--all` since it requires a source ISO file.)

### Help

```bash
bash install.sh --help
```

---

## Menu Options

When you run `sudo bash install.sh`, you will see:

```
  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
  ...
  Linux Environment Automation — v1.0.0
  Running as: root on hostname

Select a module to run:
1) System Setup      (sudo, bashrc, apt packages)
2) Network Setup     (static IP, DNS, firewall)
3) Database Setup    (PostgreSQL, MySQL, Redis)
4) Project Env Setup (Node.js, pnpm, Docker)
5) ISO Build         (build custom Linux ISO)
6) Run ALL Modules   (full environment deployment)
7) Quit
```

| Option | Description |
|---|---|
| **1 — System Setup** | Installs base apt packages, configures sudo rules, deploys `.bashrc` |
| **2 — Network Setup** | Sets static IP (optional), configures DNS, sets up ufw firewall |
| **3 — Database Setup** | Installs and configures PostgreSQL, MySQL, Redis |
| **4 — Project Env Setup** | Installs Docker, Node.js via nvm, pnpm, Python, Go |
| **5 — ISO Build** | Builds a custom bootable Linux ISO with preseed for unattended install |
| **6 — Run ALL** | Runs options 1–4 sequentially |
| **7 — Quit** | Exit the setup tool |

---

## Project Structure

```
dotfiles/
├── install.sh                  # Main entry point — interactive menu or --all/--module
├── .gitignore
├── README.md
│
├── lib/                        # Shared utilities (sourced by all modules)
│   ├── env.sh                  # Global constants — EDIT THIS before running
│   ├── log.sh                  # Logging functions (info/warn/error/success)
│   └── menu.sh                 # Interactive menu renderer
│
├── system/                     # Linux system configuration
│   ├── setup.sh                # Module entry point
│   ├── packages.sh             # Install base apt packages
│   ├── sudo.sh                 # Configure /etc/sudoers.d/ rules
│   ├── bashrc.sh               # Deploy .bashrc template + ~/.alias/ to user home
│   └── aliases.sh              # Deploy ~/.alias/ shell modules (standalone)
│
├── network/                    # Network configuration
│   ├── setup.sh                # Module entry point
│   ├── static-ip.sh            # Configure static IP via Netplan
│   ├── dns.sh                  # Configure DNS via systemd-resolved
│   └── firewall.sh             # Configure ufw firewall rules
│
├── db/                         # Database installation
│   ├── setup.sh                # Module entry point
│   ├── postgres.sh             # PostgreSQL (PGDG official repo)
│   ├── mysql.sh                # MySQL (non-interactive install)
│   └── redis.sh                # Redis (official repo, localhost-only binding)
│
├── project/                    # Development toolchain
│   ├── setup.sh                # Module entry point
│   ├── docker.sh               # Docker CE + Compose plugin
│   ├── frontend.sh             # Node.js via nvm + pnpm
│   └── backend.sh              # Python 3 + pip, Go
│
├── iso/                        # ISO builder
│   ├── build.sh                # Build custom bootable ISO via xorriso
│   └── preseed.cfg             # Debian/Ubuntu unattended install config
│
├── configs/                    # Configuration file templates
│   ├── .bashrc                 # Bash config with aliases, nvm, pnpm, Git prompt
│   ├── .gitconfig              # Git global config template
│   ├── sudoers.d/
│   │   └── 99-dotfiles         # sudoers drop-in template (__USER__ placeholder)
│   └── alias/                  # Shell alias modules (deployed to ~/.alias/)
│       ├── .bash_aliases       # Entry point — sources the 3 modules below
│       ├── .bash_env           # ANSI STYLE map, styled(), git_prompt(), build_ps1()
│       ├── .bash_git           # Git aliases + interactive branch functions
│       └── .bash_functions     # System/disk/project utility functions
│
└── logs/                       # Runtime logs (gitignored, auto-created)
    └── .gitkeep
```

---

## Module Reference

### System Module

**Entry point:** `system/setup.sh`

Runs three sub-scripts in order:

| Script | What it does |
|---|---|
| `packages.sh` | Installs base tools. Ubuntu: `apt-get` (`build-essential`, `ufw`, etc.). Rocky: `dnf` (`gcc`, `gcc-c++`, `make`, `firewalld`, etc.) + enables EPEL. |
| `sudo.sh` | Deploys `configs/sudoers.d/99-dotfiles` to `/etc/sudoers.d/`. Validates with `visudo -c` before activating. |
| `bashrc.sh` | Backs up existing `~/.bashrc`, copies `configs/.bashrc` to the deploy user's home, then deploys `configs/alias/` to `~/.alias/`. |

---

### Shell Aliases Module

**Entry point:** `system/aliases.sh`
**Menu option:** 6
**Can also run standalone:** `sudo bash system/aliases.sh`

Deploys four shell script files from `configs/alias/` to `~/.alias/` and ensures `~/.bashrc` sources the entry point.

| File | What it does |
|---|---|
| `.bash_aliases` | Entry point — sources the three modules below using `$_ALIAS_DIR` (portable, no hardcoded paths) |
| `.bash_env` | `declare -A STYLE` with 30+ ANSI codes; `styled()` helper; `git_prompt()` with 9 status symbols; `build_ps1()` sets the custom PS1 |
| `.bash_git` | `amend`, `gfm`, `gpm`, `gfp`, `gfap` aliases; `gswp` (interactive branch switch + pull); `gpcb` (push current branch with confirmation); `gcr` (checkout remote-only branch) |
| `.bash_functions` | `get_ip`, `find_path (fp)`, `disk_usage_top (dut)`, `clean_up_disk (cud)`, `run_project (run-dev/run-prod)` and more |

**`clean_up_disk` distro support:**

| Distro | Package manager used |
|---|---|
| Ubuntu / Debian | `apt-get clean`, `apt-get autoremove`, removes old kernel images |
| Rocky Linux / RHEL / Fedora | `dnf clean all`, `dnf autoremove`, `dnf remove --oldinstallonly` |

Writes the following block to `/etc/bashrc` (system-wide). If the block already exists it is removed first, then re-inserted — so re-running the script is always safe:

```bash
# --- Shell alias modules (~/.alias/) ---
# Sources .bash_env (STYLE/git_prompt/build_ps1), .bash_git, .bash_functions
[ -f ~/.alias/.bash_aliases ] && source ~/.alias/.bash_aliases

# Rebuild the custom PS1 before each prompt
PROMPT_COMMAND=build_ps1
```

**Prompt layout:**
```
[roger(staff)@hostname:192.168.1.10 ~/project (main abc123 ✔)]$
[root(root)@hostname:192.168.1.10  ~/project (main abc123 ✔)]#
```

---

### Network Module

**Entry point:** `network/setup.sh`

| Script | What it does |
|---|---|
| `static-ip.sh` | Ubuntu: writes Netplan YAML + `netplan apply`. Rocky: configures via `nmcli` (NetworkManager). Skipped if `STATIC_IP` is empty. |
| `dns.sh` | Ubuntu: writes `/etc/systemd/resolved.conf` + restarts `systemd-resolved`. Rocky: writes `/etc/NetworkManager/conf.d/dotfiles-dns.conf` + `/etc/resolv.conf`, restarts NetworkManager. |
| `firewall.sh` | Ubuntu: `ufw` (default-deny, opens `FIREWALL_ALLOW_PORTS`). Rocky: `firewalld` (same port list, permanent rules, `firewall-cmd --reload`). |

> **Warning:** Ensure port 22 is in `FIREWALL_ALLOW_PORTS` before running `firewall.sh` to prevent SSH lockout.

---

### Database Module

**Entry point:** `db/setup.sh`

| Script | What it does |
|---|---|
| `postgres.sh` | Ubuntu: PGDG apt repo. Rocky: PGDG dnf repo + `initdb`. Both: creates `DB_NAME` database and `DB_USER` role. |
| `mysql.sh` | Ubuntu: debconf preseed + apt. Rocky: MySQL official dnf repo + automatic temp-password rotation. Both: creates `DB_NAME` / `DB_USER`. |
| `redis.sh` | Ubuntu: official Redis apt repo. Rocky: EPEL. Both: binds to `127.0.0.1`, configures `REDIS_PORT`. |

---

### Project Environment Module

**Entry point:** `project/setup.sh`

| Script | What it does |
|---|---|
| `docker.sh` | Ubuntu: Docker apt repo. Rocky: Docker dnf repo (`download.docker.com/linux/centos`). Both: installs CE + Compose plugin, adds `DEPLOY_USER` to `docker` group. |
| `frontend.sh` | Installs nvm into `~/.nvm`, installs Node.js `NODE_VERSION`, sets it as default, installs pnpm globally. (Distro-agnostic.) |
| `backend.sh` | Python 3 + pip: Ubuntu uses `apt`, Rocky uses `dnf`. Go: official tarball — distro-agnostic, auto-detects arch (`uname -m` → amd64/arm64). |

---

### ISO Build Module

**Entry point:** `iso/build.sh`

Builds a customized bootable Linux ISO (preseed format — **Ubuntu/Debian source ISOs only**):

1. Installs `xorriso`: Ubuntu → `apt` (`isolinux`); Rocky → `dnf` (`syslinux`)
2. Extracts the source ISO specified by `ISO_SOURCE`
3. Injects `iso/preseed.cfg` for fully automated unattended installation
4. Patches the isolinux bootloader to auto-select preseed on boot
5. Repacks everything into a new ISO using `xorriso`

> **Note:** `preseed.cfg` is the Ubuntu/Debian installer mechanism. Rocky Linux uses `kickstart.cfg` instead — that workflow is not currently implemented in this script.

**Write to USB after building:**
```bash
sudo dd if=~/iso-build/custom-linux-YYYYMMDD.iso of=/dev/sdX bs=4M status=progress && sync
```

---

## Logging

Every module automatically writes a timestamped log file to `logs/`:

```
logs/
└── 20260430_143022_setup.log
```

Log format:
```
[2026-04-30 14:30:22] [INFO ] Starting network setup...
[2026-04-30 14:30:25] [OK   ] Static IP configured: 192.168.1.100 on eth0
[2026-04-30 14:30:26] [WARN ] Interface eth1 not found
[2026-04-30 14:30:27] [ERROR] Failed to apply Netplan config
```

Log files are excluded from version control via `.gitignore`.

---

## Adding a New Module

1. Create a directory: `mkdir my-module`
2. Create `my-module/setup.sh` with this boilerplate:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_section "My Module"
log_info "Doing something..."

# Your installation logic here

log_success "My module complete."
```

3. Make it executable: `chmod +x my-module/setup.sh`
4. Add it to `lib/menu.sh` in the `options` array and `_run_all` function
5. Add variables for it in `lib/env.sh`
