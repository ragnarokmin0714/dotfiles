#!/usr/bin/env bash
# @desc   Node.js via nvm, plus pnpm, for DEPLOY_USER
# @order  61
#
# nvm (NVM_VERSION) into ~/.nvm, Node (NODE_VERSION, default the current LTS) as the
# default version, and pnpm (PNPM_VERSION) through npm. The nvm installer is told not
# to edit ~/.bashrc (PROFILE=/dev/null): the alias library's .bash_nvm loads nvm for
# every interactive shell, so a second loader would only run it twice.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
(( EUID == 0 )) || [[ "$(id -un)" == "$DEPLOY_USER" ]] || df_is_dry || die "Run as ${DEPLOY_USER}, or with sudo"

pkg_install "${DF_N[@]}" curl ca-certificates

df_as_user "
set -euo pipefail
export NVM_DIR=\"\$HOME/.nvm\"
if [ ! -s \"\$NVM_DIR/nvm.sh\" ]; then
    curl -fsSL 'https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh' | PROFILE=/dev/null bash
fi
. \"\$NVM_DIR/nvm.sh\"
nvm install '${NODE_VERSION}'
nvm alias default '${NODE_VERSION}'
npm install -g 'pnpm@${PNPM_VERSION}'
echo \"node \$(node -v), npm \$(npm -v), pnpm \$(pnpm -v)\"
"
log_ok "Node ${NODE_VERSION} and pnpm ready for ${DEPLOY_USER}"
