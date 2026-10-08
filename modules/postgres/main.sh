#!/usr/bin/env bash
# @desc   PostgreSQL (POSTGRES_VERSION, PGDG repo) with DB_NAME owned by DB_USER
# @order  70
# @manual
#
# The PostgreSQL Global Development Group's repository on both families, so the same
# major version runs everywhere. Creating the role and database is idempotent.
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core.sh"
df_module_start
df_need_root

V="$POSTGRES_VERSION"
if [[ -z "$DB_PASSWORD" ]]; then
    df_is_dry || die "Set DB_PASSWORD in config.local.sh"
    log_warn "DB_PASSWORD is empty -- a real run would stop here"
fi
[[ "$DB_PASSWORD$DB_USER$DB_NAME" != *[\'\"\\]* ]] || die "DB_NAME / DB_USER / DB_PASSWORD may not contain quotes or backslashes"

case "$OS_FAMILY" in
    debian)
        keyring=/etc/apt/keyrings/pgdg.asc
        codename=$(. /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-}")
        if [[ ! -f "$(df_path "$keyring")" ]]; then
            df_run install -d -m 0755 /etc/apt/keyrings
            df_run curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o "$keyring"
        fi
        echo "deb [signed-by=${keyring}] https://apt.postgresql.org/pub/repos/apt ${codename}-pgdg main" \
            | df_write /etc/apt/sources.list.d/pgdg.list
        df_run apt-get update -qq
        pkg_install "${DF_N[@]}" "postgresql-${V}" "postgresql-client-${V}"
        service="postgresql"
        ;;
    rhel)
        if ! { command -v rpm &>/dev/null && rpm -q pgdg-redhat-repo &>/dev/null; }; then
            df_run dnf install -y "https://download.postgresql.org/pub/repos/yum/reporpms/EL-${OS_MAJOR}-$(uname -m)/pgdg-redhat-repo-latest.noarch.rpm"
        fi
        # The distro's own postgresql module would shadow PGDG's packages
        df_run dnf -qy module disable postgresql
        pkg_install "${DF_N[@]}" "postgresql${V}-server" "postgresql${V}"
        if [[ ! -f "/var/lib/pgsql/${V}/data/PG_VERSION" ]]; then
            df_run "/usr/pgsql-${V}/bin/postgresql-${V}-setup" initdb
        fi
        service="postgresql-${V}"
        ;;
esac
df_run systemctl enable --now "$service"

log_step "Creating role ${DB_USER} and database ${DB_NAME} (if missing)..."
df_run runuser -u postgres -- psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE "${DB_USER}" LOGIN PASSWORD '${DB_PASSWORD}';
    END IF;
END
\$\$;
SELECT 'CREATE DATABASE "${DB_NAME}" OWNER "${DB_USER}"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}')
\gexec
SQL
log_ok "PostgreSQL ${V} ready -- database ${DB_NAME}, user ${DB_USER}"
