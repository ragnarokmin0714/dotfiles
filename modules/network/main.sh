#!/usr/bin/env bash
# @desc   Network: static IPv4 address and/or DNS servers (netplan + resolved / NetworkManager)
# @order  80
# @manual
#
# Settings: STATIC_IP / SUBNET_PREFIX / GATEWAY and DNS_SERVERS in config.local.sh;
# either may be left empty. NETWORK_INTERFACE defaults to the default-route interface.
#   debian: /etc/netplan/99-dotfiles.yaml (0600, later files win) + a resolved.conf.d
#           drop-in -- the distro's own files are left alone
#   rhel:   nmcli on the interface's connection (ipv4.* and ignore-auto-dns), so
#           NetworkManager itself writes resolv.conf rather than having it overwritten
# Manual, and confirmed before applying: a wrong address cuts off an SSH session.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

if [[ -z "$STATIC_IP" && -z "$DNS_SERVERS" ]]; then
    log_info "STATIC_IP and DNS_SERVERS are both empty -- nothing to do (set them in config.local.sh)"
    exit 0
fi
iface="${NETWORK_INTERFACE:-$(ip route show default 2>/dev/null | awk '{print $5; exit}')}"
[[ -n "$iface" ]] || die "No default-route interface found -- set NETWORK_INTERFACE"
[[ -z "$STATIC_IP" || -n "$GATEWAY" ]] || die "STATIC_IP needs GATEWAY"
read -ra dns <<< "$DNS_SERVERS"

log_info "Interface ${iface}: ${STATIC_IP:+address ${STATIC_IP}/${SUBNET_PREFIX} via ${GATEWAY}}${STATIC_IP:+${DNS_SERVERS:+, }}${DNS_SERVERS:+DNS ${DNS_SERVERS}}"
if ! df_is_dry; then
    log_warn "Changing ${iface} may drop an SSH session that runs over it"
    confirm "Apply these network settings?" || { log_info "Cancelled"; exit 0; }
fi

case "$OS_FAMILY" in
    debian)
        if [[ -n "$STATIC_IP" ]]; then
            {
                echo "# Deployed by dotfiles (modules/network) -- edits are overwritten."
                echo "network:"
                echo "  version: 2"
                echo "  ethernets:"
                echo "    ${iface}:"
                echo "      dhcp4: false"
                echo "      addresses: [${STATIC_IP}/${SUBNET_PREFIX}]"
                echo "      routes:"
                echo "        - to: 0.0.0.0/0"
                echo "          via: ${GATEWAY}"
                if (( ${#dns[@]} )); then
                    echo "      nameservers:"
                    echo "        addresses: [$(IFS=,; echo "${dns[*]}")]"
                fi
            } | df_write -m 0600 /etc/netplan/99-dotfiles.yaml
            df_run netplan apply
        fi
        if (( ${#dns[@]} )); then
            printf '# Deployed by dotfiles (modules/network) -- edits are overwritten.\n[Resolve]\nDNS=%s\n' "$DNS_SERVERS" \
                | df_write /etc/systemd/resolved.conf.d/dotfiles.conf
            df_run systemctl restart systemd-resolved
        fi
        ;;
    rhel)
        con=$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)
        if [[ -z "$con" ]]; then
            df_is_dry || die "${iface} has no NetworkManager connection"
            con="<connection of ${iface}>"
        fi
        args=()
        [[ -n "$STATIC_IP" ]] && args+=(ipv4.method manual ipv4.addresses "${STATIC_IP}/${SUBNET_PREFIX}" ipv4.gateway "$GATEWAY")
        (( ${#dns[@]} )) && args+=(ipv4.dns "$(IFS=,; echo "${dns[*]}")" ipv4.ignore-auto-dns yes)
        df_run nmcli connection modify "$con" "${args[@]}"
        df_run nmcli connection up "$con"
        ;;
esac
log_ok "Network settings applied to ${iface}"
