#!/usr/bin/env bash
# =============================================================================
# db/postgres.sh — PostgreSQL Installation and Configuration
# =============================================================================
# Ubuntu / Debian  → PGDG apt repository
# Rocky / RHEL     → PGDG dnf/yum repository
#
# CONFIGURATION (set in lib/env.sh):
#   POSTGRES_VERSION — Version to install, e.g. "16"
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

log_info "Installing PostgreSQL $POSTGRES_VERSION  (distro: $DISTRO_FAMILY)"

# =============================================================================
# Ubuntu / Debian — PGDG apt repository
# =============================================================================
if [[ "$DISTRO_FAMILY" == "debian" ]]; then

  CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  PG_REPO_FILE="/etc/apt/sources.list.d/pgdg.list"

  if [[ ! -f "$PG_REPO_FILE" ]]; then
    log_info "Adding PGDG apt repository (codename: $CODENAME)..."
    curl -fsSL "https://www.postgresql.org/media/keys/ACCC4CF8.asc" \
      | gpg --dearmor -o /etc/apt/trusted.gpg.d/pgdg.gpg
    echo "deb https://apt.postgresql.org/pub/repos/apt ${CODENAME}-pgdg main" \
      > "$PG_REPO_FILE"
    apt-get update -qq
  fi

  apt-get install -y "postgresql-$POSTGRES_VERSION" "postgresql-client-$POSTGRES_VERSION"

  PG_SERVICE="postgresql@${POSTGRES_VERSION}-main"
  systemctl enable "$PG_SERVICE"
  systemctl start  "$PG_SERVICE"

# =============================================================================
# Rocky Linux / RHEL — PGDG dnf repository
# =============================================================================
elif [[ "$DISTRO_FAMILY" == "rhel" ]]; then

  RHEL_VER="$(rpm -E '%{rhel}')"
  ARCH="$(uname -m)"
  PGDG_RPM="https://download.postgresql.org/pub/repos/yum/reporpms/EL-${RHEL_VER}-${ARCH}/pgdg-redhat-repo-latest.noarch.rpm"

  if ! rpm -q pgdg-redhat-repo &>/dev/null; then
    log_info "Adding PGDG dnf repository (RHEL ${RHEL_VER}, ${ARCH})..."
    dnf install -y "$PGDG_RPM"
  fi

  # Disable the built-in PostgreSQL module to prevent version conflicts
  dnf -qy module disable postgresql 2>/dev/null || true

  dnf install -y "postgresql${POSTGRES_VERSION}-server" "postgresql${POSTGRES_VERSION}"

  # Initialize the data directory (only needed on first install)
  if [[ ! -f "/var/lib/pgsql/${POSTGRES_VERSION}/data/PG_VERSION" ]]; then
    log_info "Initializing PostgreSQL data directory..."
    "/usr/pgsql-${POSTGRES_VERSION}/bin/postgresql-${POSTGRES_VERSION}-setup" initdb
  fi

  PG_SERVICE="postgresql-${POSTGRES_VERSION}"
  systemctl enable "$PG_SERVICE"
  systemctl start  "$PG_SERVICE"

else
  log_error "Unsupported distro family: '$DISTRO_FAMILY'. Cannot install PostgreSQL."
fi

# =============================================================================
# Create application database and user (same on both distros)
# =============================================================================
log_info "Creating database '$DB_NAME' and user '$DB_USER'..."
sudo -u postgres psql -v ON_ERROR_STOP=1 << SQL
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
      CREATE ROLE "$DB_USER" LOGIN PASSWORD '$DB_PASSWORD';
    END IF;
  END
  \$\$;

  SELECT 'CREATE DATABASE "$DB_NAME" OWNER "$DB_USER"'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')
  \gexec
SQL

log_success "PostgreSQL $POSTGRES_VERSION ready. DB: $DB_NAME | User: $DB_USER"
