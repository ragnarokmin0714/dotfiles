#!/usr/bin/env bash
# @desc   HTTPS: nginx, a self-signed certificate, and a vhost redirecting HTTP to HTTPS
# @order  82
# @manual
#
# nginx from the distro; a self-signed RSA certificate for NGINX_SERVER_NAME (made once,
# kept on re-runs -- delete it to renew); the vhost rendered from vhost.conf.tmpl into
# sites-available (+ sites-enabled link) on debian or conf.d on rhel. The distro's
# default server is left alone: ours answers by server_name. nginx -t gates the reload.
# For a real certificate, put the CA-issued pair at the same two paths.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

SSL_CERT_FILE="${SSL_CERT_DIR}/dotfiles-${NGINX_SERVER_NAME}.crt"
SSL_KEY_FILE="${SSL_KEY_DIR}/dotfiles-${NGINX_SERVER_NAME}.key"

pkg_install "${DF_N[@]}" nginx openssl

if [[ -f "$(df_path "$SSL_KEY_FILE")" && -f "$(df_path "$SSL_CERT_FILE")" ]]; then
    log_ok "unchanged  ${SSL_CERT_FILE} (existing certificate kept)"
else
    df_mkdir -m 0755 "$SSL_CERT_DIR"
    df_mkdir -m 0700 "$SSL_KEY_DIR"
    df_run openssl req -x509 -nodes -newkey rsa:2048 -days "$SSL_DAYS" \
        -keyout "$(df_path "$SSL_KEY_FILE")" -out "$(df_path "$SSL_CERT_FILE")" \
        -subj "${SSL_SUBJECT}/CN=${NGINX_SERVER_NAME}"
    df_run chmod 600 "$(df_path "$SSL_KEY_FILE")"
fi

case "$OS_FAMILY" in
    debian)
        conf=/etc/nginx/sites-available/dotfiles-https.conf
        df_render_install "$DOTFILES_ROOT/modules/https/vhost.conf.tmpl" "$conf" \
            NGINX_HTTP_PORT NGINX_HTTPS_PORT NGINX_SERVER_NAME NGINX_WEB_ROOT SSL_CERT_FILE SSL_KEY_FILE
        df_run ln -sfn "$conf" /etc/nginx/sites-enabled/dotfiles-https.conf
        ;;
    rhel)
        conf=/etc/nginx/conf.d/dotfiles-https.conf
        df_render_install "$DOTFILES_ROOT/modules/https/vhost.conf.tmpl" "$conf" \
            NGINX_HTTP_PORT NGINX_HTTPS_PORT NGINX_SERVER_NAME NGINX_WEB_ROOT SSL_CERT_FILE SSL_KEY_FILE
        ;;
esac

df_run nginx -t
df_run systemctl enable nginx
df_run systemctl reload-or-restart nginx
log_ok "https://${NGINX_SERVER_NAME}:${NGINX_HTTPS_PORT} served from ${NGINX_WEB_ROOT} (self-signed)"
