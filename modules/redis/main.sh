#!/usr/bin/env bash
# @desc   Redis on 127.0.0.1:REDIS_PORT, under systemd supervision
# @order  72
# @manual
#
# Ubuntu: redis.io's repository (the archive's redis is years behind on 20.04).
# RHEL family 9: AppStream's redis, config at /etc/redis/redis.conf (EL8 kept it at
# /etc/redis.conf; both are tried). Bound to localhost only.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

case "$OS_FAMILY" in
    debian)
        keyring=/usr/share/keyrings/redis-archive-keyring.gpg
        codename=$(. /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-}")
        if [[ ! -f "$(df_path "$keyring")" ]]; then
            pkg_install "${DF_N[@]}" gnupg curl
            if df_is_dry; then
                log_info "[dry-run] fetch redis.io's key into ${keyring}"
            else
                curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o "$keyring"
            fi
        fi
        echo "deb [signed-by=${keyring}] https://packages.redis.io/deb ${codename} main" \
            | df_write /etc/apt/sources.list.d/redis.list
        df_run apt-get update -qq
        pkg_install "${DF_N[@]}" redis-server
        service=redis-server
        ;;
    rhel)
        pkg_install "${DF_N[@]}" redis
        service=redis
        ;;
esac

conf=""
for c in /etc/redis/redis.conf /etc/redis.conf; do
    [[ -f "$(df_path "$c")" ]] && { conf="$c"; break; }
done
if [[ -z "$conf" ]]; then
    df_is_dry || die "Installed redis, but found no redis.conf"
    log_info "[dry-run] set port ${REDIS_PORT}, bind 127.0.0.1 and supervised systemd in redis.conf"
else
    df_run sed -i -E \
        -e "s/^port .*/port ${REDIS_PORT}/" \
        -e "s/^#? *bind .*/bind 127.0.0.1 -::1/" \
        -e "s/^#? *supervised .*/supervised systemd/" "$conf"
fi
df_run systemctl enable "$service"
df_run systemctl restart "$service"
if ! df_is_dry; then
    redis-cli -p "$REDIS_PORT" ping | grep -q PONG || die "Redis does not answer on port ${REDIS_PORT} -- check: systemctl status ${service}"
fi
log_ok "Redis listening on 127.0.0.1:${REDIS_PORT}"
