#!/usr/bin/env bash
# @desc   Go from go.dev's official tarball -> /usr/local/go, checksum-verified
# @order  63
#
# GO_VERSION (default: the current release) for this machine's architecture, verified
# against the SHA-256 go.dev publishes before anything is extracted. PATH needs nothing:
# the alias library adds /usr/local/go/bin and ~/go/bin (.bash_env, path_add).
# Already at the wanted version: nothing to do.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

case "$(uname -m)" in
    x86_64)  arch=amd64 ;;
    aarch64) arch=arm64 ;;
    *)       die "No Go build for $(uname -m) here" ;;
esac

if df_is_dry; then
    log_info "[dry-run] download Go ${GO_VERSION} (linux-${arch}) from go.dev, verify its SHA-256, extract to /usr/local/go"
    exit 0
fi

pkg_install curl ca-certificates
version="$GO_VERSION"
[[ "$version" == latest ]] && version=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)
[[ "$version" == go* ]] || die "Could not resolve the Go version (got '${version}')"

if [[ -x /usr/local/go/bin/go ]] && [[ "$(/usr/local/go/bin/go env GOVERSION)" == "$version" ]]; then
    log_ok "Go ${version} already installed"
    exit 0
fi

tarball="${version}.linux-${arch}.tar.gz"
# go.dev's release index, one JSON array; the file's object carries its sha256
sha=$(curl -fsSL 'https://go.dev/dl/?mode=json&include=all' | tr -d ' \n' \
    | grep -o "\"filename\":\"${tarball}\"[^}]*" | grep -o '"sha256":"[0-9a-f]*"' | cut -d'"' -f4)
[[ ${#sha} -eq 64 ]] || die "No checksum published for ${tarball}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
log_step "Downloading ${tarball}..."
curl -fsSL "https://go.dev/dl/${tarball}" -o "${tmp}/${tarball}"
echo "${sha}  ${tmp}/${tarball}" | sha256sum -c --status || die "Checksum mismatch for ${tarball} -- not installed"

rm -rf /usr/local/go
tar -C /usr/local -xzf "${tmp}/${tarball}"
log_ok "$(/usr/local/go/bin/go version) installed in /usr/local/go"
