#!/usr/bin/env bash
# @desc   MySQL 8 server (distro packages) with DB_NAME and DB_USER
# @order  71
# @manual
#
# The distro's mysql-server on both families: Ubuntu's archive and RHEL 9's AppStream
# both carry 8.0, so no third-party repo is needed. root authenticates over the local
# socket (auth_socket on Ubuntu, an empty password on a fresh RHEL install), so the
# setup SQL runs as root without a password -- Ubuntu ignores the old debconf
# root-password preseed anyway.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

if [[ -z "$DB_PASSWORD" ]]; then
    df_is_dry || die "Set DB_PASSWORD in config.local.sh"
    log_warn "DB_PASSWORD is empty -- a real run would stop here"
fi
[[ "$DB_PASSWORD$DB_USER$DB_NAME" != *[\'\"\\\`]* ]] || die "DB_NAME / DB_USER / DB_PASSWORD may not contain quotes, backticks or backslashes"

pkg_install "${DF_N[@]}" mysql-server
case "$OS_FAMILY" in
    debian) service=mysql ;;
    rhel)   service=mysqld ;;
esac
df_run systemctl enable --now "$service"

log_step "Creating database ${DB_NAME} and user ${DB_USER} (if missing)..."
df_run mysql --user=root <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
SQL
log_ok "MySQL ready -- database ${DB_NAME}, user ${DB_USER}"
