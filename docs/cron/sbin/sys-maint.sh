#!/bin/bash

# ── Environment ───────────────────────────────────────────────────────────────
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
shopt -s expand_aliases        # enable alias expansion under non-interactive (cron) execution

# ── Load functions ────────────────────────────────────────────────────────────
source /etc/bashrc 2>/dev/null || {
    log_err "Failed to load /etc/bashrc"
    exit 1
}

# ── Run ───────────────────────────────────────────────────────────────────────
log_banner "System Maintenance"
log_head "Start: $(now)"

sys_maintain    # works: calling function directly
# sys-maint    # skipped: alias is not available in non-interactive shell

log_head "End: $(now)"
log_ok "System maintenance finished"