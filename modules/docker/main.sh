#!/usr/bin/env bash
# @desc   Rootless Docker CE + compose/buildx from Docker's repo, run by DEPLOY_USER
# @order  60
#
# Docker's own repository on both families: download.docker.com/linux/<ubuntu|debian>
# for apt, /linux/rhel for RHEL and /linux/centos for Rocky and Alma, which is what
# Docker documents for EL rebuilds.
#
# Rootless only: membership of group docker is root on the host without a password, so
# the system daemon stays off and DEPLOY_USER runs their own dockerd under systemd
# --user. slirp4netns is its network (vpnkit, the fallback, ships for amd64 only).
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

if [[ "$DEPLOY_USER" == root ]]; then
    df_is_dry || die "Rootless Docker needs a non-root DEPLOY_USER (config.local.sh)"
    log_warn "DEPLOY_USER is root -- a real run would stop here"
fi
if ! grep -qs "^${DEPLOY_USER}:" "$(df_path /etc/subuid)" || ! grep -qs "^${DEPLOY_USER}:" "$(df_path /etc/subgid)"; then
    df_is_dry || die "${DEPLOY_USER} has no range in /etc/subuid or /etc/subgid -- add one (usermod --add-subuids/--add-subgids, 65536 ids)"
    log_warn "${DEPLOY_USER} has no /etc/subuid or /etc/subgid range -- a real run would stop here"
fi

PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
          docker-ce-rootless-extras uidmap slirp4netns dbus-user-session)

case "$OS_FAMILY" in
    debian)
        keyring=/etc/apt/keyrings/docker.asc
        arch=$(dpkg --print-architecture 2>/dev/null || echo amd64)
        codename=$(. /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-}")
        if [[ ! -f "$(df_path "$keyring")" ]]; then
            df_run install -d -m 0755 /etc/apt/keyrings
            df_run curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" -o "$keyring"
            df_run chmod a+r "$keyring"
        fi
        echo "deb [arch=${arch} signed-by=${keyring}] https://download.docker.com/linux/${OS_ID} ${codename} stable" \
            | df_write /etc/apt/sources.list.d/docker.list
        df_run apt-get update -qq
        ;;
    rhel)
        repo=centos
        [[ "$OS_ID" == rhel ]] && repo=rhel
        pkg_install "${DF_N[@]}" dnf-plugins-core
        if [[ ! -f "$(df_path /etc/yum.repos.d/docker-ce.repo)" ]]; then
            df_run dnf config-manager --add-repo "https://download.docker.com/linux/${repo}/docker-ce.repo"
        fi
        ;;
esac

pkg_install "${DF_N[@]}" "${PACKAGES[@]}"

# The packages enable the system daemon; rootless means it never runs.
df_run systemctl disable --now docker.service docker.socket
if id -nG "$DEPLOY_USER" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
    df_run gpasswd -d "$DEPLOY_USER" docker
    log_info "${DEPLOY_USER} left group docker -- takes effect at the next login"
fi

# --memory/--cpus/--pids-limit need cgroup v2 controllers delegated to user sessions.
printf '[Service]\nDelegate=cpu cpuset io memory pids\n' \
    | df_write /etc/systemd/system/user@.service.d/dotfiles-delegate.conf
df_run systemctl daemon-reload
[[ -f /sys/fs/cgroup/cgroup.controllers ]] \
    || log_warn "cgroup v1 host: rootless containers run, but resource limits are not enforced"

# Ubuntu 24.04+ forbids unprivileged user namespaces unless a profile allows them.
if [[ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" == 1 ]]; then
    printf '%s\n' 'abi <abi/4.0>,' 'include <tunables/global>' '' \
        '/usr/bin/rootlesskit flags=(unconfined) {' '  userns,' '' \
        '  include if exists <local/usr.bin.rootlesskit>' '}' \
        | df_write /etc/apparmor.d/usr.bin.rootlesskit
    df_run apparmor_parser -r /etc/apparmor.d/usr.bin.rootlesskit
fi

# Linger keeps the user's systemd -- and so their dockerd -- running without a login.
df_run loginctl enable-linger "$DEPLOY_USER"
df_as_user "
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=\$XDG_RUNTIME_DIR/bus
[ -f \"\$HOME/.config/systemd/user/docker.service\" ] || dockerd-rootless-setuptool.sh install
systemctl --user enable --now docker
docker context inspect rootless >/dev/null 2>&1 \
    || docker context create rootless --docker host=unix://\$XDG_RUNTIME_DIR/docker.sock >/dev/null
docker context use rootless >/dev/null
docker info --format 'rootless dockerd {{.ServerVersion}}, security: {{.SecurityOptions}}'
"
log_ok "Rootless Docker ready for ${DEPLOY_USER}"
