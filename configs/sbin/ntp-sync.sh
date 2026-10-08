cat > /usr/local/sbin/ntp-sync.sh << 'EOF'
#!/bin/bash

# ── Environment ───────────────────────────────────────────────────────────────
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
shopt -s expand_aliases        # enable alias expansion under non-interactive (cron) execution

# ── Check NTP sync status ─────────────────────────────────────────────────────
synced=$(timedatectl show --property=NTPSynchronized --value 2>/dev/null)

# ── Load functions ────────────────────────────────────────────────────────────
source /etc/bashrc 2>/dev/null || {
    log_err "Failed to load /etc/bashrc"
    exit 1
}

# ── Run ───────────────────────────────────────────────────────────────────────
if [[ "$synced" != "yes" ]]; then
    log_banner "NTP Sync"
    log_head "Start: $(now)"

    log_warn "System clock is not synchronized, running ntp-sync..."
    ntp-sync    # works: calling function directly

    log_head "End: $(now)"
    log_ok "NTP sync finished"
fi

EOF

# ── Set permissions (owner execute only — root) ───────────────────────────────────────────────────────────
chmod 700 /usr/local/sbin/ntp-sync.sh    # correct filename