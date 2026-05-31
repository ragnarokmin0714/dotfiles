#!/usr/bin/env bash
# =============================================================================
# project/backend.sh — Backend Tooling Installation
# =============================================================================
# Installs backend language runtimes and tools.
# Currently installs:
#   - Python 3 + pip + venv
#   - Go (latest stable via official tarball — distro-agnostic)
#
# Supports Ubuntu/Debian (apt) and Rocky/RHEL (dnf).
#
# REQUIRES: sudo / root privileges
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_info "Installing backend toolchain  (distro: $DISTRO_FAMILY)"

# =============================================================================
# Python 3
# =============================================================================
log_info "Installing Python 3 + pip + venv..."

if [[ "$DISTRO_FAMILY" == "debian" ]]; then
  apt-get install -y python3 python3-pip python3-venv
elif [[ "$DISTRO_FAMILY" == "rhel" ]]; then
  dnf install -y python3 python3-pip
  # venv is built-in to python3 on RHEL family; no separate package needed
else
  log_error "Unsupported distro family: '$DISTRO_FAMILY'. Cannot install Python."
fi

python3 --version
log_success "Python 3 installed."

# =============================================================================
# Go — official tarball (distro-agnostic)
# Map uname -m → Go arch names:
#   x86_64  → amd64   (most servers)
#   aarch64 → arm64   (Apple M1/M2 Linux VMs, Raspberry Pi 4 64-bit)
# =============================================================================
case "$(uname -m)" in
  x86_64)  GO_ARCH="amd64"  ;;
  aarch64) GO_ARCH="arm64"  ;;
  armv7l)  GO_ARCH="armv6l" ;;
  *)       GO_ARCH="$(uname -m)" ;;
esac

GO_VERSION="$(curl -fsSL https://go.dev/VERSION?m=text | head -1)"
GO_TARBALL="${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
GO_INSTALL_DIR="/usr/local"

log_info "Installing Go $GO_VERSION (arch: $GO_ARCH)..."
curl -fsSL "https://go.dev/dl/$GO_TARBALL" -o "/tmp/$GO_TARBALL"
rm -rf "$GO_INSTALL_DIR/go"
tar -C "$GO_INSTALL_DIR" -xzf "/tmp/$GO_TARBALL"
rm -f "/tmp/$GO_TARBALL"

if [[ ! -f /etc/profile.d/go.sh ]]; then
  echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
fi

export PATH="$PATH:/usr/local/go/bin"
go version
log_success "Go $GO_VERSION installed at $GO_INSTALL_DIR/go."
