#!/usr/bin/env bash
# =============================================================================
# db/mysql.sh — MySQL Installation and Configuration
# =============================================================================
# Ubuntu / Debian  → MySQL official apt repository + debconf preseed
# Rocky / RHEL     → MySQL official dnf/yum repository
#
# CONFIGURATION (set in lib/env.sh):
#   MYSQL_VERSION    — Version to install, e.g. "8.0"
#   DB_ROOT_PASSWORD — MySQL root password
#   DB_USER          — Application database user to create
#   DB_PASSWORD      — Password for DB_USER
#   DB_NAME          — Application database name to create
#
# REQUIRES: sudo / root privileges
# =============================================================================
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/lib/env.sh"
source "$DOTFILES_ROOT/lib/log.sh"

log_info "Installing MySQL $MYSQL_VERSION  (distro: $DISTRO_FAMILY)"

# =============================================================================
# Ubuntu / Debian — apt + debconf preseed
# =============================================================================
if [[ "$DISTRO_FAMILY" == "debian" ]]; then

  log_info "Pre-seeding MySQL root password for non-interactive install..."
  debconf-set-selections <<< "mysql-server mysql-server/root_password password $DB_ROOT_PASSWORD"
  debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $DB_ROOT_PASSWORD"

  DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server

  MYSQL_SERVICE="mysql"
  systemctl enable "$MYSQL_SERVICE"
  systemctl start  "$MYSQL_SERVICE"

  MYSQL_ROOT_ARGS=(-u root -p"$DB_ROOT_PASSWORD")

# =============================================================================
# Rocky Linux / RHEL — dnf + MySQL official repo
# =============================================================================
elif [[ "$DISTRO_FAMILY" == "rhel" ]]; then

  RHEL_VER="$(rpm -E '%{rhel}')"
  MYSQL_MAJOR="${MYSQL_VERSION//./}"   # "8.0" → "80"

  if ! rpm -q mysql-community-server &>/dev/null; then
    log_info "Adding MySQL $MYSQL_VERSION repo (RHEL ${RHEL_VER})..."
    dnf install -y \
      "https://dev.mysql.com/get/mysql${MYSQL_MAJOR}-community-release-el${RHEL_VER}-1.noarch.rpm"
    dnf install -y mysql-community-server
  fi

  MYSQL_SERVICE="mysqld"
  systemctl enable "$MYSQL_SERVICE"
  systemctl start  "$MYSQL_SERVICE"

  # MySQL on RHEL generates a temporary root password on first start
  TEMP_PASS="$(grep 'temporary password' /var/log/mysqld.log 2>/dev/null | tail -1 | awk '{print $NF}')"

  if [[ -n "$TEMP_PASS" ]]; then
    log_info "Found temporary MySQL root password — changing it now..."
    mysql --connect-expired-password -u root -p"$TEMP_PASS" \
      -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';"
  fi

  MYSQL_ROOT_ARGS=(-u root -p"$DB_ROOT_PASSWORD")

else
  log_error "Unsupported distro family: '$DISTRO_FAMILY'. Cannot install MySQL."
fi

# =============================================================================
# Create application database and user (same on both distros)
# =============================================================================
log_info "Creating MySQL database '$DB_NAME' and user '$DB_USER'..."
mysql "${MYSQL_ROOT_ARGS[@]}" << SQL
  CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

  CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
  GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
  FLUSH PRIVILEGES;
SQL

log_success "MySQL $MYSQL_VERSION ready. DB: $DB_NAME | User: $DB_USER"
