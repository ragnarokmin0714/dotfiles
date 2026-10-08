#!/usr/bin/env bash
# @desc   sudo: passwordless rules for DEPLOY_USER (services, network, docker, packages)
# @order  40
# @manual
#
# Manual on purpose: the template grants package managers and docker, which are
# root-equivalent (see configs/sudoers.d/dotfiles.tmpl). The rendered file is checked
# with visudo before it lands -- a broken drop-in can lock everyone out of sudo.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

[[ "$DEPLOY_USER" != root ]] || die "DEPLOY_USER is root -- there is nothing to grant (set DEPLOY_USER in config.local.sh)"
# sudo skips drop-ins whose name contains a dot (or ends in ~)
safe_name="${DEPLOY_USER//[^A-Za-z0-9_-]/_}"
df_render_install -m 0440 -v df_check_sudoers \
    "$DOTFILES_ROOT/configs/sudoers.d/dotfiles.tmpl" "/etc/sudoers.d/dotfiles-${safe_name}" DEPLOY_USER
log_ok "sudo rules in place for ${DEPLOY_USER}"
