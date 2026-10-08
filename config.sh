#!/usr/bin/env bash
# @file config.sh
# @brief Deploy-time settings: what the modules configure.
# @description
#   Committed defaults, safe to run as they are. Put anything host-specific or
#   secret in config.local.sh (gitignored, sourced after this file) -- start from
#   config.local.example.sh. Platform facts (OS_*, PKG_MGR, paths) are not set here:
#   the runtime library detects them (configs/alias/.bash_env).
#   Every value is ${VAR:-default}, so the environment can override it per run:
#     NODE_VERSION=20 sudo -E bash install.sh node

# --- User being set up --------------------------------------------------------
# DEPLOY_USER defaults to whoever ran sudo (lib/core.sh); set it to configure another.
# DEPLOY_USER=roger

# --- network: static IP + DNS (modules/network) ---------------------------------
NETWORK_INTERFACE="${NETWORK_INTERFACE:-}"        # empty = the default-route interface
STATIC_IP="${STATIC_IP:-}"                        # empty = leave addressing alone
SUBNET_PREFIX="${SUBNET_PREFIX:-24}"
GATEWAY="${GATEWAY:-}"
DNS_SERVERS="${DNS_SERVERS:-}"                    # e.g. "1.1.1.1 8.8.8.8"; empty = leave DNS alone

# --- firewall (modules/firewall) -------------------------------------------------
# Declarative: the firewall ends up allowing exactly these TCP ports. 22 is required.
# shellcheck disable=SC2206  # word-splits an environment override like "22 80" on purpose
FIREWALL_ALLOW_PORTS=(${FIREWALL_ALLOW_PORTS[*]:-22 80 443})

# --- https: nginx + self-signed certificate (modules/https) ----------------------
NGINX_SERVER_NAME="${NGINX_SERVER_NAME:-localhost}"
NGINX_HTTP_PORT="${NGINX_HTTP_PORT:-80}"
NGINX_HTTPS_PORT="${NGINX_HTTPS_PORT:-443}"
NGINX_WEB_ROOT="${NGINX_WEB_ROOT:-/var/www/html}"
SSL_DAYS="${SSL_DAYS:-365}"
SSL_SUBJECT="${SSL_SUBJECT:-/C=TW/ST=Taiwan/L=Taipei/O=dotfiles}"   # CN is added from NGINX_SERVER_NAME
case "$OS_FAMILY" in
    rhel) SSL_CERT_DIR="${SSL_CERT_DIR:-/etc/pki/tls/certs}";  SSL_KEY_DIR="${SSL_KEY_DIR:-/etc/pki/tls/private}" ;;
    *)    SSL_CERT_DIR="${SSL_CERT_DIR:-/etc/ssl/certs}";      SSL_KEY_DIR="${SSL_KEY_DIR:-/etc/ssl/private}" ;;
esac

# --- databases (modules/postgres, modules/mysql, modules/redis) ------------------
# Passwords have no default on purpose: the modules refuse to run until they are set
# in config.local.sh.
DB_NAME="${DB_NAME:-appdb}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-}"
POSTGRES_VERSION="${POSTGRES_VERSION:-16}"        # from the PGDG repo, both families
REDIS_PORT="${REDIS_PORT:-6379}"

# --- toolchains (modules/node, modules/go) ---------------------------------------
NVM_VERSION="${NVM_VERSION:-v0.40.8}"
NODE_VERSION="${NODE_VERSION:-lts/*}"             # anything `nvm install` accepts
PNPM_VERSION="${PNPM_VERSION:-latest}"
GO_VERSION="${GO_VERSION:-latest}"                # e.g. go1.23.4; latest = go.dev's current

# --- iso (modules/iso, experimental) ---------------------------------------------
ISO_SOURCE="${ISO_SOURCE:-}"
ISO_OUTPUT_DIR="${ISO_OUTPUT_DIR:-$HOME/iso-build}"
ISO_LABEL="${ISO_LABEL:-CUSTOM-LINUX}"
