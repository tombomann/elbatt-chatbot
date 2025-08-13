#!/usr/bin/env bash
set -euo pipefail

echo "=== Elbatt Chatbot Deploy (env + redis + caddy + backend) ==="

APP_DIR="/opt/elbatt-chatbot"
SERVICE_NAME="elbatt-chatbot.service"
UNIT_PATH="/etc/systemd/system/${SERVICE_NAME}"
DOMAIN_DEFAULT="chatbot.elbatt.no"

# --- Sudo check ---
if [ "$EUID" -ne 0 ]; then
  echo "Kjør meg med sudo: sudo $0"
  exit 1
fi

# --- Pakker ---
apt update
DEBIAN_FRONTEND=noninteractive apt install -y \
  python3 python3-venv python3-pip \
  git curl \
  redis-server caddy

# --- Redis ---
systemctl enable redis-server
systemctl restart redis-server
redis-cli ping || true

# --- Frigjør port 80 (Caddy trenger den) ---
if ss -ltnp | grep -q ':80'; then
  if systemctl is-active --quiet nginx; then
    systemctl stop nginx || true
    systemctl disable nginx || true
  fi
  if systemctl is-active --quiet apache2; then
    systemctl stop apache2 || true
    systemctl disable apache2 || true
  fi
fi

# --- App-dir ---
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# --- Repo inn/oppdater ---
if [ ! -d ".git" ]; then
  echo "Repo ikke initialisert – kloner…"
  git init
  git remote add origin https://github.com/tombomann/elbatt-chatbot.git
  git fetch origin main
  git checkout -t origin/main
else
  echo "Repo finnes – oppdaterer…"
  git fetch origin main
  git reset --hard origin/main
fi

# --- Sørg for at services/ finnes (import-feilen din var pga manglende mappe) ---
if [ ! -d "${APP_DIR}/services" ]; then
  echo "ADVARSEL: services/-mappen mangler i repoet. Backend vil feile på imports."
  echo "Fortsetter, men sjekk at repoet inneholder services/."
fi

# --- .env (hemmeligheter + config) ---
ENV_FILE="${APP_DIR}/.env"
if [ ! -f "$ENV_FILE" ]; then
  cat >"$ENV_FILE" <<'EOF'
# === Elbatt Chatbot .env ===
# Sett riktig verdier før produksjon
PORT=8000
CORS_ALLOW_ALL=false
ALLOWED_ORIGINS=https://elbatt.no,https://www.elbatt.no,https://chatbot.elbatt.no

# Nøkler/tokens
OPENAI_API_KEY=sk-SETT-MEG
VEGVESEN_API_KEY=SETT-MEG

# Redis
REDIS_URL=redis://127.0.0.1:6379/0

# Domenenavn (for Caddy)
DOMAIN=chatbot.elbatt.no
EOF
  echo "Opprettet .env-mal i ${ENV_FILE}. Oppdater nøklene!"
fi

# --- Les DOMAIN fra .env (eller default) ---
DOMAIN="$(grep -E '^DOMAIN=' "$ENV_FILE" | cut -d= -f2- || true)"
DOMAIN="${DOMAIN:-$DOMAIN_DEFAULT}"

# --- Python venv + pakker ---
python3 -m venv "${APP_DIR}/venv"
"${APP_DIR}/venv/bin/pip" install --upgrade pip wheel
if [ -f "${APP_DIR}/requirements.txt" ]; then
  "${APP_DIR}/venv/bin/pip" install -r "${APP_DIR}/requirements.txt"
else
  echo "FANT IKKE requirements.txt i ${APP_DIR} – fortsetter, men dette vil trolig feile."
fi

# --- (Valgfritt) Playwright-browsere hvis pakken er installert ---
if "${APP_DIR}/venv/bin/python" -c "import importlib.util,sys; sys.exit(0) if importlib.util.find_spec('playwright') is None else sys.exit(1)"; then
  echo "Playwright ikke installert – hopper over browser install."
else
  "${APP_DIR}/venv/bin/python" -m playwright install --with-deps chromium || true
fi

# --- systemd service (leser EnvironmentFile=.env) ---
cat >"$UNIT_PATH" <<EOF
[Unit]
Description=Elbatt Chatbot backend (FastAPI/Uvicorn)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
EnvironmentFile=-${ENV_FILE}
ExecStart=${APP_DIR}/venv/bin/uvicorn chatbot_api:app --host 0.0.0.0 --port \$PORT
Restart=on-failure
RestartSec=3
TimeoutStopSec=15

# Herding (justér ved Playwright issues)
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"

# --- Caddy config (HTTPS reverse proxy) ---
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

cat >/etc/caddy/Caddyfile <<EOF
${DOMAIN} {
    encode zstd gzip
    reverse_proxy 127.0.0.1:\${PORT}
    log {
        output file /var/log/caddy/chatbot_access.log
    }
    tls {
        issuer acme
    }
}
EOF

systemctl enable caddy
systemctl restart caddy

# --- Health checks ---
echo "Venter 2s og tester…"
sleep 2
echo "Backend health (lokalt):"
curl -sf http://127.0.0.1:"$(grep -E '^PORT=' "$ENV_FILE" | cut -d= -f2- || echo 8000)"/health || true
echo
echo "Via Caddy/HTTPS:"
curl -vk https://"${DOMAIN}"/health || true
echo
echo "=== Deploy ferdig! ==="
echo "-> Rediger hemmeligheter i ${ENV_FILE} og kjør: systemctl restart ${SERVICE_NAME}"
