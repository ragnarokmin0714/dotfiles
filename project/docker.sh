#!/usr/bin/env bash
# =============================================================================
# project/docker.sh — Docker CE + Docker Compose Plugin Installation
# =============================================================================
# Ubuntu / Debian  → Official Docker apt repository
# Rocky / RHEL     → Official Docker dnf repository (CentOS stream)
#
# Adds deploy user to the "docker" group for non-root usage.
#
# REQUIRES: sudo / root privileges
# NOTE: The user must log out and back in for the docker group to take effect.
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

DOCKER_PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)

log_info "Installing Docker CE  (distro: $DISTRO_FAMILY)"

# =============================================================================
# Ubuntu / Debian — Docker apt repository
# =============================================================================
if [[ "$DISTRO_FAMILY" == "debian" ]]; then

  DOCKER_GPG="/etc/apt/keyrings/docker.gpg"
  CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  ARCH="$(dpkg --print-architecture)"

  if [[ ! -f "$DOCKER_GPG" ]]; then
    log_info "Adding Docker apt repository (codename: $CODENAME, arch: $ARCH)..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" \
      | gpg --dearmor -o "$DOCKER_GPG"
    chmod a+r "$DOCKER_GPG"
    echo "deb [arch=$ARCH signed-by=$DOCKER_GPG] \
    https://download.docker.com/linux/ubuntu $CODENAME stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
  fi

  apt-get install -y "${DOCKER_PACKAGES[@]}"

# =============================================================================
# Rocky Linux / RHEL — Docker dnf repository
# =============================================================================
elif [[ "$DISTRO_FAMILY" == "rhel" ]]; then

  if ! dnf repolist | grep -q "docker-ce-stable"; then
    log_info "Adding Docker dnf repository..."
    dnf config-manager --add-repo \
      https://download.docker.com/linux/centos/docker-ce.repo
  fi

  dnf install -y "${DOCKER_PACKAGES[@]}"

else
  log_error "Unsupported distro family: '$DISTRO_FAMILY'. Cannot install Docker."
fi

# =============================================================================
# Post-install (same on both distros)
# =============================================================================
systemctl enable docker
systemctl start  docker

usermod -aG docker "$DEPLOY_USER"
log_info "User '$DEPLOY_USER' added to docker group. Re-login required to apply."

docker --version
docker compose version

log_success "Docker installed successfully."
