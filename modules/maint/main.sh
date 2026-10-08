#!/usr/bin/env bash
# @desc   Maintenance: daily update + cleanup, NTP check (cron), their logs and rotation
# @order  30
#
#   configs/sbin/        -> SBIN_DIR       (0750)  sys-maint.sh, ntp-sync.sh
#   configs/logrotate.d/ -> LOGROTATE_DIR  (0644)  rotation for DOTFILES_LOG_DIR/*.log
#   configs/cron.d/      -> CRON_DIR       (0644)  the schedule
# The scripts source the deployed alias library (sys_maintain, ntp_sync, log_*), so the
# shell module must have run. Each file is validated before it lands: bash -n,
# logrotate's own parser, and cron's naming and newline rules.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

if [[ ! -f "$(df_path "$ALIAS_DIR/.bash_aliases")" ]] && ! (( DF_DRY_RUN )); then
    die "The maintenance scripts load ${ALIAS_DIR} -- deploy it first: install.sh shell maint"
fi

pkg_install "${DF_N[@]}" cron logrotate
df_mkdir -m 0755 "$DOTFILES_LOG_DIR"
df_install_dir -m 0750 -v df_check_bash      "$DOTFILES_ROOT/configs/sbin"        "$SBIN_DIR"
df_install_dir -m 0644 -v df_check_logrotate "$DOTFILES_ROOT/configs/logrotate.d" "$LOGROTATE_DIR"
df_install_dir -m 0644 -v df_check_cron      "$DOTFILES_ROOT/configs/cron.d"      "$CRON_DIR"

case "$OS_FAMILY" in
    debian) df_run systemctl enable --now cron ;;
    rhel)   df_run systemctl enable --now crond ;;
esac
log_ok "Maintenance scheduled -- logs in ${DOTFILES_LOG_DIR}"
