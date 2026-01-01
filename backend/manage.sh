#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/home/salesnote}"
UNIT_TEMPLATE="/etc/systemd/system/salesnote@.service"
UNIT_GROUP="/etc/systemd/system/salesnote.service"
NGINX_TEMPLATE="${APP_DIR}/nginx.conf.template"
NGINX_OUT="${APP_DIR}/nginx.conf"

usage() {
  cat <<EOF
Usage: manage.sh <command> [count]

Commands:
  scale <count>       Install units if needed, enable, start/stop to match count, regen nginx, reload
  status <count>      Status of N instances

Env overrides:
  APP_DIR=/path/to/backend
  NGINX_SERVER_NAME=example.com
  SSL_CERT_PATH=/etc/letsencrypt/live/example.com/fullchain.pem
  SSL_KEY_PATH=/etc/letsencrypt/live/example.com/privkey.pem
EOF
}

load_env() {
  if [ -f "${APP_DIR}/.env" ]; then
    set -a
    . "${APP_DIR}/.env"
    set +a
  fi
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
require_count() {
  if [ "${1:-}" = "" ]; then
    echo "Missing instance count." >&2
    usage
    exit 1
  fi
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
  sed "s|{{UPSTREAM_SERVERS}}|${servers}|g; s|{{SSL_BLOCK}}|${ssl_block}|g" "${NGINX_TEMPLATE}" > "${NGINX_OUT}"
  echo "Generated ${NGINX_OUT}"
}

reload_nginx() {
  require_root
  if command -v systemctl >/dev/null 2>&1; then
    systemctl reload nginx
  else
    nginx -s reload
  fi
}

cmd="${1:-}"
case "$cmd" in
  scale)
    require_count "${2:-}"
    local_count="$2"
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
    require_count "${2:-}"
    status_instances "$2"
    ;;
  *)
    usage
    exit 1
    ;;
esac
