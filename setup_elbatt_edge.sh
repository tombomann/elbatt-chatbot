#!/usr/bin/env bash
# setup_elbatt_edge.sh
# Setter opp Nginx edge for chatbot.elbatt.no + valgfri S3-opplasting og verifikasjon.

set -Eeuo pipefail
IFS=$'\n\t'

# === Konfigurerbare variabler ===
HOST="chatbot.elbatt.no"
MYSTORE_URL="https://www.elbatt.no/"
MODE="${MODE:-s3}"            # 's3' (proxy til S3) eller 'local' (serve /srv/public/embed.js)
ROOT_DIR="${ROOT_DIR:-/srv/public}"

# TLS (Let's Encrypt)
CERT_FULLCHAIN="/etc/letsencrypt/live/${HOST}/fullchain.pem"
CERT_PRIVKEY="/etc/letsencrypt/live/${HOST}/privkey.pem"

# Nginx-stier
VHOST_AVAILABLE="/etc/nginx/sites-available/${HOST}.conf"
VHOST_ENABLED="/etc/nginx/sites-enabled/${HOST}.conf"

# S3 (Scaleway)
S3CMD_CFG="${S3CMD_CFG:-$HOME/.s3cfg-elbatt}"
S3_HOST="${S3_HOST:-s3.fr-par.scw.cloud}"
S3_BUCKET="${S3_BUCKET:-elbatt-cdn}"
S3_URL="https://${S3_BUCKET}.${S3_HOST}"
S3_EMBED_PATH="embed.js"
S3_HEALTH_PATH="health"
EMBED_LOCAL="${EMBED_LOCAL:-./embed.js}"
HEALTH_LOCAL="${HEALTH_LOCAL:-/tmp/health}"

# === Hjelpefunksjoner ===
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Mangler kommando: $1"; exit 1; }; }
ts() { date +"%Y-%m-%d %H:%M:%S"; }

fail() {
  echo "[$(ts)] ERROR: $*" >&2
  exit 1
}

info() { echo "[$(ts)] $*"; }

backup_if_exists() {
  local f="$1"
  [[ -e "$f" ]] && cp -a "$f" "${f}.bak.$(date +%Y%m%d-%H%M%S)" && info "Backup -> ${f}.bak.*"
}

write_vhost_s3() {
  info "Skriver Nginx vhost (S3-proxy) til: ${VHOST_AVAILABLE}"
  cat > "${VHOST_AVAILABLE}" <<'NGINX'
server {
    listen 80;
    server_name chatbot.elbatt.no;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name chatbot.elbatt.no;

    ssl_certificate     /etc/letsencrypt/live/chatbot.elbatt.no/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/chatbot.elbatt.no/privkey.pem;

    # Presis helsesjekk
    location = /health {
        add_header Content-Type text/plain always;
        return 200 "ok\n";
    }

    # Leverer widget via Scaleway S3-proxy
    location = /embed.js {
        proxy_pass https://elbatt-cdn.s3.fr-par.scw.cloud/embed.js;
        proxy_set_header Host elbatt-cdn.s3.fr-par.scw.cloud;  # SNI/vhost
        proxy_ssl_server_name on;
        add_header Cache-Control "public, max-age=3600, immutable" always;
        add_header Content-Type "application/javascript" always;
    }
}
NGINX
}

write_vhost_local() {
  info "Skriver Nginx vhost (lokal fil) til: ${VHOST_AVAILABLE}"
  mkdir -p "${ROOT_DIR}"
  cat > "${VHOST_AVAILABLE}" <<'NGINX'
server {
    listen 80;
    server_name chatbot.elbatt.no;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name chatbot.elbatt.no;

    ssl_certificate     /etc/letsencrypt/live/chatbot.elbatt.no/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/chatbot.elbatt.no/privkey.pem;

    root /srv/public;

    # Presis helsesjekk
    location = /health {
        add_header Content-Type text/plain always;
        return 200 "ok\n";
    }

    # Leverer widget fra disk
    location = /embed.js {
        try_files /embed.js =404;
        add_header Cache-Control "public, max-age=3600, immutable" always;
        add_header Content-Type "application/javascript" always;
    }
}
NGINX
}

enable_only_this_vhost() {
  info "Aktiverer kun denne vhosten for ${HOST}"
  ln -sf "${VHOST_AVAILABLE}" "${VHOST_ENABLED}"

  # Fjern andre som også hevder samme server_name
  mapfile -t extras < <(grep -R -l -E "server_name\s+${HOST//./\\.}" /etc/nginx/sites-enabled || true)
  for f in "${extras[@]}"; do
    [[ "$f" != "${VHOST_ENABLED}" ]] && { rm -f "$f"; info "Fjernet ekstra symlink: $f"; }
  done

  # Vanlig støy
  rm -f /etc/nginx/sites-enabled/default || true
}

nginx_test_reload() {
  info "Tester Nginx-konfigurasjon"
  nginx -t || {
    echo "---------- ${VHOST_AVAILABLE} ----------"
    nl -ba "${VHOST_AVAILABLE}" | sed -n '1,200p'
    echo "----------------------------------------"
    fail "Nginx test feilet"
  }

  info "Laster Nginx på nytt"
  systemctl reload nginx || fail "reload feilet"
}

s3_upload_if_present() {
  [[ "${MODE}" != "s3" ]] && return 0
  need_cmd s3cmd

  if [[ -f "${EMBED_LOCAL}" ]]; then
    info "Laster opp embed.js til S3"
    s3cmd -c "${S3CMD_CFG}" \
      --host="${S3_HOST}" --host-bucket="%(bucket)s.${S3_HOST}" \
      --add-header='Cache-Control: public, max-age=3600, immutable' \
      put "${EMBED_LOCAL}" "s3://${S3_BUCKET}/${S3_EMBED_PATH}" --acl-public || fail "s3cmd put embed.js feilet"
  else
    info "Hopper over opplasting: ${EMBED_LOCAL} finnes ikke"
  fi

  printf "ok\n" > "${HEALTH_LOCAL}"
  info "Laster opp /health til S3"
  s3cmd -c "${S3CMD_CFG}" \
    --host="${S3_HOST}" --host-bucket="%(bucket)s.${S3_HOST}" \
    --add-header='Cache-Control: max-age=30' \
    put "${HEALTH_LOCAL}" "s3://${S3_BUCKET}/${S3_HEALTH_PATH}" --acl-public || fail "s3cmd put health feilet"
}

verify_edge() {
  local url_edge="https://${HOST}"
  local url_s3="${S3_URL}/${S3_EMBED_PATH}"

  info "Verifiserer ${url_edge}/health"
  curl -si "${url_edge}/health" | head -n1

  info "Verifiserer headere for ${url_edge}/embed.js"
  curl -si "${url_edge}/embed.js" | awk 'tolower($0) ~ /^(http\/|content-type|cache-control|etag|last-modified)/ {print}'

  info "Sjekker at Mystore-HTML inneholder script-tag"
  if curl -s "${MYSTORE_URL}" | grep -Fq 'https://chatbot.elbatt.no/embed.js'; then
    echo "✅ Fant <script src=\"https://chatbot.elbatt.no/embed.js\" defer></script> på ${MYSTORE_URL}"
  else
    echo "⚠️  Fant ikke script-tag på ${MYSTORE_URL}"
  fi

  info "Sammenligner ETag/Last-Modified mellom edge og S3"
  echo "-- EDGE --"
  curl -sI "${url_edge}/embed.js" | egrep -i '^(etag|last-modified|content-length|date|age|x-cache):'
  echo "--  S3  --"
  curl -sI "${url_s3}" | egrep -i '^(etag|last-modified|content-length|date|age|x-cache):'

  info "IPv4 vs IPv6-respons (topp 5 linjer)"
  echo "-- IPv4 --"
  curl -sI4 "${url_edge}/embed.js" | sed -n '1,5p'
  echo "-- IPv6 --"
  curl -sI6 "${url_edge}/embed.js" | sed -n '1,5p'

  info "Lister server_name forekomster (diagnostikk)"
  nginx -T | awk '/server {/ {i++} /server_name/ {print "server["i"]", $0}'
}

# === Main ===
need_cmd nginx
need_cmd curl
need_cmd grep
need_cmd awk
need_cmd sed
need_cmd ln
need_cmd tee
need_cmd systemctl

# Sørg for at certs finnes (kun advarsel)
[[ -f "${CERT_FULLCHAIN}" && -f "${CERT_PRIVKEY}" ]] || \
  echo "⚠️  Finner ikke LE-sertifikater enda i ${CERT_FULLCHAIN} / ${CERT_PRIVKEY} (håper du har dem)."

backup_if_exists "${VHOST_AVAILABLE}"

case "${MODE}" in
  s3)    write_vhost_s3 ;;
  local) write_vhost_local ;;
  *) fail "Ukjent MODE='${MODE}', bruk 's3' eller 'local'" ;;
esac

enable_only_this_vhost
nginx_test_reload

# Valgfritt S3-opplasting (gjør ingenting om embed.js ikke finnes lokalt)
s3_upload_if_present || true

verify_edge

info "Ferdig ✅"
