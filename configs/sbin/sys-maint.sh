#!/usr/bin/env bash
# @file sys-maint.sh
# @brief Daily maintenance: upgrade every package, then clean up disk. Unattended.
# @description
#   Deployed to /usr/local/sbin by the maint module; run as root by cron
#   (/etc/cron.d/dotfiles-maint), output appended to /var/log/dotfiles/sys-maint.log
#   (rotated by /etc/logrotate.d/dotfiles). The work is the alias library's
#   sys_maintain -- the same command as `sys-maint` in a shell -- with -y, so neither
#   apt nor dnf can stop to ask a question nobody is there to answer.
#   Exit status is sys_maintain's, so a failure shows in cron mail and in the log.
set -uo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# The deployed library, not /etc/bashrc: Ubuntu's /etc/bash.bashrc returns at once in a
# non-interactive shell, so going through it would leave every function undefined.
# shellcheck source=/dev/null
source /etc/profile.d/.alias/.bash_aliases || { echo "sys-maint: alias library missing (run: dotfiles shell)" >&2; exit 1; }

log_banner "System Maintenance"
log_head "Start: $(date "$NOW_FMT")"
sys_maintain -y
rc=$?
log_head "End: $(date "$NOW_FMT")"
if (( rc == 0 )); then log_ok "System maintenance finished"; else log_err "System maintenance failed (exit ${rc})"; fi
exit "$rc"
