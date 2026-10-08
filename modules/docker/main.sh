#!/usr/bin/env bash
# @desc   Docker CE + compose/buildx plugins from Docker's repo; DEPLOY_USER joins group docker
# @order  60
#
# Docker's own repository on both families: download.docker.com/linux/<ubuntu|debian>
# for apt, /linux/rhel for RHEL and /linux/centos for Rocky and Alma, which is what
# Docker documents for EL rebuilds.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)

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
df_run systemctl enable --now docker
if [[ "$DEPLOY_USER" != root ]]; then
    df_run usermod -aG docker "$DEPLOY_USER"
    log_info "${DEPLOY_USER} is in group docker -- takes effect at the next login"
fi
log_ok "Docker installed"
