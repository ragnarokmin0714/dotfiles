#!/usr/bin/env bash
# @desc   Development and test tools (SYS_DEVTEST: xvfb, xauth) for GUI tests on screenless hosts
# @order  64
# @manual
#
# Opt-in: left out of --all, because each tool is attack surface a host only needs
# when it builds and tests software. The list and why each entry is there live in
# SYS_DEVTEST (configs/alias/.bash_env); installing goes through sys_devtest -- the
# same command you run by hand. Xvfb itself is never started here: run_headless
# (.bash_dev) starts a locked-down instance per command and stops it afterwards.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

sys_devtest "${DF_N[@]}"
log_ok "Development and test tools in place -- run GUI tests with: headless <command>"
