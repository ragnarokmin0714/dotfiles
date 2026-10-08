#!/usr/bin/env bash
# @desc   Base packages: build tools, certificates, archivers + the CLI toolkit (git, jq, htop, ...)
# @order  10
#
# The build plumbing other modules rely on, then SYS_TOOLKIT (configs/alias/.bash_env)
# through sys_toolkit -- the same command you run by hand, so a host set up here and a
# host topped up interactively end up identical. Names are distro-neutral; the RHEL
# spellings come from PKG_NAME_MAP. On the RHEL family EPEL and CRB come first: the
# toolkit's htop and lnav live there.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

BASE_PACKAGES=(build-essential ca-certificates gnupg wget unzip vim net-tools)

case "$PKG_MGR" in
    apt) df_run apt-get update -qq ;;
    dnf) df_run dnf makecache -q ;;
esac
pkg_install "${DF_N[@]}" "${BASE_PACKAGES[@]}"
sys_toolkit "${DF_N[@]}"
log_ok "Base packages and toolkit in place"
