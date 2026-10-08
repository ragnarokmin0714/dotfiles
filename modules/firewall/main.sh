#!/usr/bin/env bash
# @desc   Firewall: inbound TCP allowed on exactly FIREWALL_ALLOW_PORTS, the rest denied
# @order  81
# @manual
#
# Declarative: existing port rules are replaced by FIREWALL_ALLOW_PORTS (config.sh), so
# re-running converges instead of piling up rules. ufw on debian, firewalld on rhel.
# Refuses a list without 22, and asks before resetting the rules.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

[[ " ${FIREWALL_ALLOW_PORTS[*]} " == *" 22 "* ]] || die "Port 22 (SSH) is not in FIREWALL_ALLOW_PORTS -- refusing to lock you out"
log_info "Allowed inbound TCP after this: ${FIREWALL_ALLOW_PORTS[*]}"
if ! df_is_dry; then
    confirm "Replace the current firewall rules?" || { log_info "Cancelled"; exit 0; }
fi

case "$OS_FAMILY" in
    debian)
        pkg_install "${DF_N[@]}" ufw
        df_run ufw --force reset
        df_run ufw default deny incoming
        df_run ufw default allow outgoing
        for port in "${FIREWALL_ALLOW_PORTS[@]}"; do df_run ufw allow "${port}/tcp"; done
        df_run ufw --force enable
        df_is_dry || ufw status verbose
        ;;
    rhel)
        pkg_install "${DF_N[@]}" firewalld
        df_run systemctl enable --now firewalld
        df_run firewall-cmd --set-default-zone=public
        if ! df_is_dry; then
            for existing in $(firewall-cmd --permanent --list-ports); do
                firewall-cmd --permanent --remove-port="$existing" >/dev/null
            done
        fi
        for port in "${FIREWALL_ALLOW_PORTS[@]}"; do df_run firewall-cmd --permanent --add-port="${port}/tcp"; done
        df_run firewall-cmd --reload
        df_is_dry || firewall-cmd --list-ports
        ;;
esac
log_ok "Firewall allows TCP ${FIREWALL_ALLOW_PORTS[*]}"
