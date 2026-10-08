#!/usr/bin/env bash
# @desc   Python 3 with pip and venv, from the distro
# @order  62
#
# The distro's python3: what system tools are built against, and what both families
# patch. On the RHEL family venv is part of python3 (PKG_NAME_MAP maps it to nothing).
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

pkg_install "${DF_N[@]}" python3 python3-pip python3-venv
df_is_dry || python3 --version
log_ok "Python 3 ready"
