#!/usr/bin/env bash
# =============================================================================
# db/redis.sh — Redis Installation and Configuration
# =============================================================================
# Ubuntu / Debian  → Official Redis apt repository (packages.redis.io)
# Rocky / RHEL     → EPEL repository
#
# Configures Redis to listen on localhost only (secure default).
#
# CONFIGURATION (set in lib/env.sh):
#   REDIS_PORT — Port Redis listens on (default: 6379)
#
# REQUIRES: sudo / root privileges
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

REDIS_CONF="/etc/redis/redis.conf"

log_info "Installing Redis  (distro: $DISTRO_FAMILY)"

# =============================================================================
# Ubuntu / Debian — official Redis apt repository
# =============================================================================
if [[ "$DISTRO_FAMILY" == "debian" ]]; then

  log_info "Adding Redis apt repository..."
  curl -fsSL https://packages.redis.io/gpg \
    | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg

  CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] \
  https://packages.redis.io/deb ${CODENAME} main" \
    > /etc/apt/sources.list.d/redis.list
  apt-get update -qq
  apt-get install -y redis-server

  REDIS_SERVICE="redis-server"

# =============================================================================
# Rocky Linux / RHEL — EPEL
# =============================================================================
elif [[ "$DISTRO_FAMILY" == "rhel" ]]; then

  if ! rpm -q epel-release &>/dev/null; then
    log_info "Enabling EPEL repository..."
    dnf install -y epel-release
  fi

  log_info "Installing redis via EPEL..."
  dnf install -y redis

  REDIS_CONF="/etc/redis.conf"   # Path differs on RHEL family
  REDIS_SERVICE="redis"

else
  log_error "Unsupported distro family: '$DISTRO_FAMILY'. Cannot install Redis."
fi

# =============================================================================
# Configure Redis (same settings on both distros)
# =============================================================================
log_info "Configuring Redis on port $REDIS_PORT (bind 127.0.0.1 only)..."

sed -i "s/^port .*/port $REDIS_PORT/" "$REDIS_CONF"
sed -i "s/^# bind 127.0.0.1/bind 127.0.0.1/" "$REDIS_CONF"
sed -i "s/^bind .*/bind 127.0.0.1/" "$REDIS_CONF"
sed -i "s/^supervised no/supervised systemd/" "$REDIS_CONF"

systemctl enable "$REDIS_SERVICE"
systemctl restart "$REDIS_SERVICE"

if redis-cli -p "$REDIS_PORT" ping | grep -q "PONG"; then
  log_success "Redis is running on port $REDIS_PORT."
else
  log_error "Redis ping failed. Check: systemctl status $REDIS_SERVICE"
fi
