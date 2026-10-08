#!/usr/bin/env bash
# @file ntp-sync.sh
# @brief Re-sync the clock, but only when it is not synchronized. Unattended.
# @description
#   Deployed to /usr/local/sbin by the maint module; cron runs it every 10 minutes and
#   once after boot (/etc/cron.d/dotfiles-maint). Silent while the clock is in sync, so
#   /var/log/dotfiles/ntp-sync.log only grows when something was wrong.
set -uo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[[ "$(timedatectl show --property=NTPSynchronized --value 2>/dev/null)" == yes ]] && exit 0

# shellcheck source=/dev/null
source /etc/profile.d/.alias/.bash_aliases || { echo "ntp-sync: alias library missing (run: dotfiles shell)" >&2; exit 1; }

log_banner "NTP Sync"
log_warn "System clock is not synchronized -- re-syncing"
ntp_sync
rc=$?
if (( rc == 0 )); then log_ok "NTP sync finished"; else log_err "NTP sync failed (exit ${rc})"; fi
exit "$rc"
