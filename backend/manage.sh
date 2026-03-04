#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/home/salesnote}"
UNIT_TEMPLATE="/etc/systemd/system/salesnote@.service"
UNIT_GROUP="/etc/systemd/system/salesnote.service"
NGINX_TEMPLATE="${APP_DIR}/nginx.conf.template"
NGINX_OUT="${APP_DIR}/nginx.conf"
NGINX_SITE_AVAILABLE="/etc/nginx/sites-available/salesnote"
NGINX_SITE_ENABLED="/etc/nginx/sites-enabled/salesnote"
NGINX_DEFAULT_SITE="/etc/nginx/sites-enabled/default"
NGINX_MAIN_CONF="/etc/nginx/nginx.conf"
NGINX_SYSTEMD_OVERRIDE_DIR="/etc/systemd/system/nginx.service.d"
NGINX_SYSTEMD_OVERRIDE_FILE="${NGINX_SYSTEMD_OVERRIDE_DIR}/limits.conf"
POSTGRES_MAX_CONNECTIONS="${POSTGRES_MAX_CONNECTIONS:-100}"
DATABASE_URL=""

usage() {
  cat <<EOF
Usage: manage.sh <command>

Commands:
  start               Install units if needed, ensure dependencies, start the single API instance, regen nginx, reload
  stop                Stop and disable all salesnote instances
  status              Show status of the single API instance

Env overrides:
  APP_DIR=/path/to/backend
  SALESNOTE__DATABASE_URL=postgres://user:password@127.0.0.1:5432/dbname
  NGINX_SERVER_NAME=example.com
  SSL_CERT_PATH=/etc/letsencrypt/live/example.com/fullchain.pem
  SSL_KEY_PATH=/etc/letsencrypt/live/example.com/privkey.pem
  NGINX_WORKER_PROCESSES=auto
  NGINX_WORKER_CONNECTIONS=8192
  NGINX_LIMIT_NOFILE=65535
  POSTGRES_MAX_CONNECTIONS=100
EOF
}

load_env() {
  if [ -f "${APP_DIR}/.env" ]; then
    set -a
    . "${APP_DIR}/.env"
    set +a
  fi
  DATABASE_URL="${SALESNOTE__DATABASE_URL:-${DATABASE_URL:-}}"
  if [ -n "${NGINX_SERVER_NAME:-}" ]; then
    SSL_CERT_PATH="/etc/letsencrypt/live/${NGINX_SERVER_NAME}/fullchain.pem"
    SSL_KEY_PATH="/etc/letsencrypt/live/${NGINX_SERVER_NAME}/privkey.pem"
  fi
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root (sudo)." >&2
    exit 1
  fi
}

ensure_nginx() {
  require_root
  if command -v nginx >/dev/null 2>&1; then
    return
  fi
  echo "Nginx not found. Installing..."
  timeout 300 apt-get update || { echo "apt-get update timed out"; exit 1; }
  timeout 300 apt-get install -y nginx || { echo "apt-get install timed out"; exit 1; }
  systemctl enable nginx
  systemctl start nginx
}

ensure_redis() {
  require_root
  if ! command -v redis-server >/dev/null 2>&1; then
    echo "Redis not found. Installing..."
    timeout 300 apt-get update || { echo "apt-get update timed out"; exit 1; }
    timeout 300 apt-get install -y redis-server || { echo "apt-get install timed out"; exit 1; }
  fi
  systemctl enable redis-server
  systemctl start redis-server
}

sql_escape_literal() {
  printf "%s" "$1" | sed "s/'/''/g"
}

sql_escape_ident() {
  printf "%s" "$1" | sed 's/"/""/g'
}

parse_database_url() {
  load_env

  if [ -z "${DATABASE_URL}" ]; then
    echo "DATABASE_URL not set. Skipping PostgreSQL bootstrap."
    return 1
  fi

  local url="${DATABASE_URL#postgres://}"
  url="${url#postgresql://}"

  local creds_host="${url%%/*}"
  DB_NAME="${url#*/}"
  DB_NAME="${DB_NAME%%\?*}"

  if [ "${creds_host}" = "${url}" ] || [ -z "${DB_NAME}" ]; then
    echo "Unsupported DATABASE_URL format: ${DATABASE_URL}" >&2
    exit 1
  fi

  local creds="${creds_host%@*}"
  local host_port="${creds_host#*@}"

  if [ "${creds}" = "${creds_host}" ] || [ -z "${creds}" ] || [ -z "${host_port}" ]; then
    echo "Unsupported DATABASE_URL format: ${DATABASE_URL}" >&2
    exit 1
  fi

  DB_USER="${creds%%:*}"
  DB_PASS="${creds#*:}"
  DB_HOST="${host_port%%:*}"
  DB_PORT="${host_port##*:}"

  if [ "${DB_USER}" = "${creds}" ] || [ -z "${DB_PASS}" ]; then
    echo "DATABASE_URL must include username and password." >&2
    exit 1
  fi

  if [ "${DB_HOST}" = "${host_port}" ]; then
    DB_PORT="5432"
  fi

  if [ -z "${DB_USER}" ] || [ -z "${DB_NAME}" ] || [ -z "${DB_HOST}" ]; then
    echo "DATABASE_URL is missing required parts." >&2
    exit 1
  fi
}

ensure_postgres() {
  require_root

  if command -v psql >/dev/null 2>&1 || \
     systemctl list-unit-files postgresql.service 2>/dev/null | grep -q '^postgresql\.service'; then
    echo "PostgreSQL already present on server; skipping PostgreSQL management."
    return 0
  fi

  parse_database_url || return 0

  case "${DB_HOST}" in
    127.0.0.1|localhost|::1)
      ;;
    *)
      echo "DATABASE_URL host is ${DB_HOST}; skipping local PostgreSQL install/setup."
      return 0
      ;;
  esac

  echo "PostgreSQL not found. Installing..."
  apt-get update
  apt-get install -y postgresql postgresql-contrib

  if ! systemctl start postgresql; then
    echo "Warning: could not start postgresql service. Skipping PostgreSQL management."
    return 0
  fi

  local postgres_conf
  postgres_conf="$(find /etc/postgresql -path '*/main/postgresql.conf' | head -n 1)"
  if [ -z "${postgres_conf}" ]; then
    echo "Warning: could not find postgresql.conf under /etc/postgresql. Skipping PostgreSQL management."
    return 0
  fi

  sed -i "s/^[#[:space:]]*max_connections[[:space:]]*=.*/max_connections = ${POSTGRES_MAX_CONNECTIONS}/" "${postgres_conf}"

  if ! systemctl restart postgresql; then
    echo "Warning: could not restart postgresql service after config update. Skipping PostgreSQL management."
    return 0
  fi

  local role_ident
  local db_ident
  local role_lit
  local db_lit
  local pass_lit

  role_ident="$(sql_escape_ident "${DB_USER}")"
  db_ident="$(sql_escape_ident "${DB_NAME}")"
  role_lit="$(sql_escape_literal "${DB_USER}")"
  db_lit="$(sql_escape_literal "${DB_NAME}")"
  pass_lit="$(sql_escape_literal "${DB_PASS}")"

  sudo -u postgres psql -v ON_ERROR_STOP=1 postgres <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${role_lit}') THEN
        CREATE ROLE "${role_ident}" LOGIN PASSWORD '${pass_lit}';
    ELSE
        ALTER ROLE "${role_ident}" WITH LOGIN PASSWORD '${pass_lit}';
    END IF;
END
\$\$;
EOF

  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = '${db_lit}'" postgres | grep -q 1; then
    sudo -u postgres createdb -O "${DB_USER}" "${DB_NAME}"
  else
    sudo -u postgres psql -v ON_ERROR_STOP=1 postgres \
      -c "ALTER DATABASE \"${db_ident}\" OWNER TO \"${role_ident}\";"
  fi
}

require_count() {
  if [ "${1:-}" = "" ]; then
    echo "Missing instance count." >&2
    usage
    exit 1
  fi
  case "$1" in
    ''|*[!0-9]*)
      echo "Instance count must be a non-negative integer." >&2
      exit 1
      ;;
  esac
}

instance_ports() {
  local count="$1"
  for i in $(seq 1 "$count"); do
    echo $((8080 + i))
  done
}

install_units() {
  require_root
  cp "${APP_DIR}/salesnote@.service" "${UNIT_TEMPLATE}"
  cp "${APP_DIR}/salesnote.service" "${UNIT_GROUP}"
  systemctl daemon-reload
}

enable_instances() {
  local count="$1"
  for port in $(instance_ports "$count"); do
    systemctl enable "salesnote@${port}"
  done
}

disable_instances() {
  local count="$1"
  for port in $(instance_ports "$count"); do
    systemctl disable "salesnote@${port}" || true
  done
}

start_instances() {
  local count="$1"
  for port in $(instance_ports "$count"); do
    systemctl start "salesnote@${port}"
  done
}

stop_instances() {
  local count="$1"
  for port in $(instance_ports "$count"); do
    systemctl stop "salesnote@${port}" || true
  done
}

restart_instances() {
  local count="$1"
  for port in $(instance_ports "$count"); do
    systemctl restart "salesnote@${port}"
  done
}

status_instances() {
  local count="$1"
  for port in $(instance_ports "$count"); do
    systemctl status "salesnote@${port}" --no-pager
  done
}

uninstall_units() {
  require_root
  rm -f "${UNIT_TEMPLATE}" "${UNIT_GROUP}"
  systemctl daemon-reload
}

gen_nginx() {
  local count="$1"
  if [ ! -f "${NGINX_TEMPLATE}" ]; then
    echo "Missing nginx template: ${NGINX_TEMPLATE}" >&2
    exit 1
  fi
  load_env
  local servers=""
  for port in $(instance_ports "$count"); do
    servers="${servers}    server 127.0.0.1:${port};"$'\n'
  done
  local server_name="${NGINX_SERVER_NAME:-_}"
  local ssl_block=""
  if [ -n "${SSL_CERT_PATH:-}" ] && [ -n "${SSL_KEY_PATH:-}" ]; then
    ssl_block=$(cat <<EOF
server {
    listen 80;
    server_name ${server_name};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${server_name};

    ssl_certificate     ${SSL_CERT_PATH};
    ssl_certificate_key ${SSL_KEY_PATH};

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_pass http://salesnote_api;
    }
}
EOF
)
  else
    ssl_block=$(cat <<EOF
server {
    listen 80;
    server_name ${server_name};

    location / {
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_pass http://salesnote_api;
    }
}
EOF
)
  fi
  UPSTREAM_SERVERS="${servers}" SSL_BLOCK="${ssl_block}" \
    perl -0pe 's/\{\{UPSTREAM_SERVERS\}\}/$ENV{UPSTREAM_SERVERS}/g; s/\{\{SSL_BLOCK\}\}/$ENV{SSL_BLOCK}/g' \
    "${NGINX_TEMPLATE}" > "${NGINX_OUT}"
  echo "Generated ${NGINX_OUT}"
}

reload_nginx() {
  require_root
  local worker_processes="${NGINX_WORKER_PROCESSES:-auto}"
  local worker_connections="${NGINX_WORKER_CONNECTIONS:-8192}"
  local limit_nofile="${NGINX_LIMIT_NOFILE:-65535}"
  if [ ! -f "${NGINX_MAIN_CONF}" ]; then
    echo "Missing nginx main config: ${NGINX_MAIN_CONF}" >&2
    exit 1
  fi
  mkdir -p "${NGINX_SYSTEMD_OVERRIDE_DIR}"
  cat > "${NGINX_SYSTEMD_OVERRIDE_FILE}" <<EOF
[Service]
LimitNOFILE=${limit_nofile}
EOF
  systemctl daemon-reload
  WORKER_PROCESSES="${worker_processes}" WORKER_CONNECTIONS="${worker_connections}" \
    perl -0pi -e '
      s/^\s*worker_processes\s+\S+;/worker_processes $ENV{WORKER_PROCESSES};/m;
      s/events\s*\{.*?\}/events {\n    worker_connections $ENV{WORKER_CONNECTIONS};\n    multi_accept on;\n}/s;
    ' "${NGINX_MAIN_CONF}"
  cp "${NGINX_OUT}" "${NGINX_SITE_AVAILABLE}"
  ln -sf "${NGINX_SITE_AVAILABLE}" "${NGINX_SITE_ENABLED}"
  rm -f "${NGINX_DEFAULT_SITE}"
  nginx -t
  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart nginx
  else
    nginx -s reload
  fi
}

cmd="${1:-}"
case "$cmd" in
  start)
    local_count=1
    ensure_postgres
    ensure_nginx
    ensure_redis
    install_units
    enable_instances "$local_count"
    for port in $(instance_ports "$local_count"); do
      if ! systemctl is-active --quiet "salesnote@${port}"; then
        systemctl start "salesnote@${port}"
      fi
    done
    for unit in $(systemctl list-units --all --type=service --no-legend "salesnote@*.service" | awk '{print $1}'); do
      port="${unit#salesnote@}"
      port="${port%.service}"
      if [ "$port" -ge $((8080 + local_count + 1)) ]; then
        systemctl stop "salesnote@${port}" || true
        systemctl disable "salesnote@${port}" || true
      fi
    done
    gen_nginx "$local_count"
    reload_nginx
    ;;
  status)
    status_instances 1
    ;;
  stop)
    for unit in $(systemctl list-units --all --type=service --no-legend "salesnote@*.service" | awk '{print $1}'); do
      port="${unit#salesnote@}"
      port="${port%.service}"
      systemctl stop "salesnote@${port}" || true
      systemctl disable "salesnote@${port}" || true
    done
    ;;
  *)
    usage
    exit 1
    ;;
esac
