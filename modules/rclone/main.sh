#!/usr/bin/env bash
# @desc   rclone from downloads.rclone.org's official zip -> /usr/local/bin, checksum-verified
# @order  65
# @manual
#
# Opt-in: only hosts that sync with cloud storage need it. RCLONE_VERSION (default: the
# current release) for this machine's architecture, verified against the SHA256SUMS
# rclone publishes next to the zip before anything is installed. Remotes and their
# tokens live in ~/.config/rclone/rclone.conf, which is never part of this repo.
# Already at the wanted version: nothing to do.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

case "$(uname -m)" in
    x86_64)  arch=amd64 ;;
    aarch64) arch=arm64 ;;
    *)       die "No rclone build for $(uname -m) here" ;;
esac

if df_is_dry; then
    log_info "[dry-run] download rclone ${RCLONE_VERSION} (linux-${arch}) from downloads.rclone.org, verify its SHA-256, install to /usr/local/bin/rclone"
    exit 0
fi

pkg_install curl ca-certificates unzip
version="$RCLONE_VERSION"
[[ "$version" == latest ]] && version=$(curl -fsSL 'https://downloads.rclone.org/version.txt' | awk '{print $2}')
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Could not resolve the rclone version (got '${version}')"

if [[ -x /usr/local/bin/rclone ]] && [[ "$(/usr/local/bin/rclone version | awk 'NR==1 {print $2}')" == "$version" ]]; then
    log_ok "rclone ${version} already installed"
    exit 0
fi

name="rclone-${version}-linux-${arch}"
# one "<sha256>  <file>" line per build, inside a PGP-signed message
sha=$(curl -fsSL "https://downloads.rclone.org/${version}/SHA256SUMS" | awk -v f="${name}.zip" '$2 == f {print $1}')
[[ ${#sha} -eq 64 ]] || die "No checksum published for ${name}.zip"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
log_step "Downloading ${name}.zip..."
curl -fsSL "https://downloads.rclone.org/${version}/${name}.zip" -o "${tmp}/${name}.zip"
echo "${sha}  ${tmp}/${name}.zip" | sha256sum -c --status || die "Checksum mismatch for ${name}.zip -- not installed"

unzip -q "${tmp}/${name}.zip" -d "$tmp"
df_install -m 0755 "${tmp}/${name}/rclone" /usr/local/bin/rclone
log_ok "$(/usr/local/bin/rclone version | head -1) installed in /usr/local/bin"
