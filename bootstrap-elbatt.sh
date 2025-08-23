#!/usr/bin/env bash
set -Eeuo pipefail

# -----------------------------------------------
# Elbatt one-shot bootstrap: Makefile + secrets + deploy-cdn + systemd
# -----------------------------------------------

ROOT_DIR="${ROOT_DIR:-/root/elbatt-chatbot}"
DOMAIN="${DOMAIN:-chatbot.elbatt.no}"
BUCKET="${BUCKET:-elbatt-cdn}"
REGION="${REGION:-fr-par}"
KEY="${KEY:-embed.js}"
SRC_REL="${SRC_REL:-backend/static/embed.js}"
CDN_URL="${CDN_URL:-https://chatbot.elbatt.no}"

# ---- sanity ----
mkdir -p "$ROOT_DIR" "$ROOT_DIR/scripts"
cd "$ROOT_DIR"

say(){ printf "\n==> %s\n" "$*"; }
note(){ printf "   -> %s\n" "$*"; }

# -----------------------------------------------
# scripts/render-env.sh
# -----------------------------------------------
say "Skriver scripts/render-env.sh"
cat > "$ROOT_DIR/scripts/render-env.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
# Henter hemmeligheter fra Scaleway Secret Manager og skriver en sikker env‑fil.
OUT="${OUT:-/etc/elbatt-chatbot.env}"
umask 077

need() { command -v "$1" >/dev/null 2>&1 || { echo "Mangler $1"; exit 1; }; }
need scw

fetch() {
  local key="$1"
  scw secret version access get "$key"
}

cat > "$OUT" <<ENV
# Autogenerert av render-env.sh (ikke commit denne fila)
OPENAI_API_KEY=$(fetch OPENAI_API_KEY || true)
OPENAI_MODEL=${OPENAI_MODEL:-gpt-4o-mini}

VEGVESEN_API_KEY=$(fetch VEGVESEN_API_KEY || true)
VEGVESEN_ENDPOINT=${VEGVESEN_ENDPOINT:-https://akfell-datautlevering.atlas.vegvesen.no/enkeltoppslag/kjoretoydata?kjennemerke=SU18018}

GH_PAT=$(fetch GH_PAT || true)
SONAR_TOKEN=$(fetch SONAR_TOKEN || true)

NETLIFY_AUTH_TOKEN=$(fetch NETLIFY_AUTH_TOKEN || true)
NETLIFY_SITE_ID=$(fetch NETLIFY_SITE_ID || true)

# S3 (Scaleway Object Storage) – kun hvis du har lagret disse som secrets:
AWS_ACCESS_KEY_ID=$(fetch AWS_ACCESS_KEY_ID || true)
AWS_SECRET_ACCESS_KEY=$(fetch AWS_SECRET_ACCESS_KEY || true)
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-fr-par}
AWS_S3_FORCE_PATH_STYLE=true

ALLOWED_ORIGINS=${ALLOWED_ORIGINS:-https://elbatt.no,https://www.elbatt.no,https://chatbot.elbatt.no}
PORT=${PORT:-8000}
ENV
chmod 600 "$OUT"
echo "✅ Skrev $OUT"
EOF
chmod +x "$ROOT_DIR/scripts/render-env.sh"

# -----------------------------------------------
# deploy_cdn.sh
# -----------------------------------------------
say "Skriver deploy_cdn.sh"
cat > "$ROOT_DIR/deploy_cdn.sh" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

BUCKET="\${BUCKET:-$BUCKET}"
REGION="\${REGION:-$REGION}"
SRC="\${SRC:-$SRC_REL}"
KEY="\${KEY:-$KEY}"
CDN_URL="\${CDN_URL:-$CDN_URL}"

say(){ printf "\\n==> %s\\n" "\$*"; }

[ -f "\$SRC" ] || { echo "❌ Fant ikke \$SRC (kjør fra repo-rota eller sett SRC=)"; exit 1; }

# Foretrekk AWS CLI mot Scaleway S3 (med endpoint-url)
if command -v aws >/dev/null 2>&1; then
  : "\${AWS_DEFAULT_REGION:=\$REGION}"
  : "\${AWS_S3_FORCE_PATH_STYLE:=true}"
  say "Laster opp med AWS CLI → s3://\$BUCKET/\$KEY"
  aws s3 cp "\$SRC" "s3://\$BUCKET/\$KEY" \
    --endpoint-url "https://s3.\$REGION.scw.cloud" \
    --acl public-read \
    --content-type "application/javascript" \
    --cache-control "public, max-age=3600, immutable"

# Fallback: ingen aws → si ifra
else
  echo "❌ AWS CLI ikke funnet. Installer eller bruk GitHub Actions-jobben."
  exit 1
fi

# Purge Scaleway Object‑CDN cache (hvis SCW_SECRET_KEY finnes)
if [ -n "\${SCW_SECRET_KEY:-}" ]; then
  say "Purger CDN cache for /\$KEY"
  curl -fsS -X POST \\
    -H "Content-Type: application/json" \\
    -H "X-Auth-Token: \${SCW_SECRET_KEY}" \\
    -d "{\\"paths\\":[\\"/\$KEY\\"]}" \\
    "https://api.scaleway.com/object/v1/regions/\$REGION/buckets/\$BUCKET/cache/purge" >/dev/null \
    && echo "✅ Purge OK" || echo "⚠️ Purge feilet – cache utløper automatisk"
else
  echo "ℹ️ SCW_SECRET_KEY ikke satt – hopper over purge (cache utløper automatisk)"
fi

say "Ferdig. Test URL:"
echo "👉 \${CDN_URL}/\${KEY}"
EOF
chmod +x "$ROOT_DIR/deploy_cdn.sh"

# -----------------------------------------------
# Makefile (secrets + deploy-cdn + tester)
# -----------------------------------------------
say "Skriver Makefile"
cat > "$ROOT_DIR/Makefile" <<'EOF'
SHELL := /usr/bin/env bash
DOMAIN ?= chatbot.elbatt.no
REGION ?= fr-par
BUCKET ?= elbatt-cdn
KEY    ?= embed.js
SRC    ?= backend/static/embed.js

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make secrets       - hent secrets fra Scaleway og skriv /etc/elbatt-chatbot.env"
	@echo "  make deploy-cdn    - last opp embed.js til S3 + (valgfritt) purge CDN"
	@echo "  make test-embed    - HEAD mot https://$(DOMAIN)/embed.js"
	@echo "  make test-preflight- OPTIONS preflight mot /api/chat"
	@echo "  make test-post     - POST mot /api/chat (viser status/headers)"
	@echo "  make systemd-reload/restart/status"

.PHONY: secrets
secrets:
	@sudo /root/elbatt-chatbot/scripts/render-env.sh

.PHONY: deploy-cdn
deploy-cdn:
	@/root/elbatt-chatbot/deploy_cdn.sh

.PHONY: test-embed
test-embed:
	@curl -sI https://$(DOMAIN)/$(KEY) | sed -n '1p;/^content-type/I p;/^cache-control/I p'

.PHONY: test-preflight
test-preflight:
	@curl -si -X OPTIONS https://$(DOMAIN)/api/chat \
	 -H "Origin: https://www.elbatt.no" \
	 -H "Access-Control-Request-Method: POST" \
	 -H "Access-Control-Request-Headers: content-type" | sed -n '1,25p'

.PHONY: test-post
test-post:
	@curl -si https://$(DOMAIN)/api/chat \
	 -H "Origin: https://www.elbatt.no" -H "Content-Type: application/json" \
	 --data '{"message":"ping"}' | sed -n '1,25p'

.PHONY: systemd-reload systemd-restart systemd-status
systemd-reload:
	@sudo systemctl daemon-reload

systemd-restart:
	@sudo systemctl restart elbatt-chatbot || true

systemd-status:
	@systemctl status elbatt-chatbot --no-pager || true
EOF

# -----------------------------------------------
# systemd unit – kjører render-env.sh før appstart
# ExecStart er bevisst ufarlig til du peker den mot din app.
# -----------------------------------------------
say "Skriver systemd‑unit: /etc/systemd/system/elbatt-chatbot.service"
cat > /etc/systemd/system/elbatt-chatbot.service <<'EOF'
[Unit]
Description=Elbatt Chatbot (env render + app)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
# Kjør secrets-render før oppstart
ExecStartPre=/usr/bin/env bash -lc '/root/elbatt-chatbot/scripts/render-env.sh'
EnvironmentFile=/etc/elbatt-chatbot.env

# TODO: Pek denne til din faktiske app når klar:
# Eksempel FastAPI:
# ExecStart=/usr/bin/env bash -lc 'cd /root/elbatt-chatbot && uvicorn backend.main:app --host 0.0.0.0 --port ${PORT:-8000}'
# Midlertidig "noop" som minner deg på å endre:
ExecStart=/usr/bin/env bash -lc 'echo "[elbatt-chatbot] Sett ExecStart til din app (se unit-fil)."; sleep infinity'

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# -----------------------------------------------
# Tips og (valgfri) enable
# -----------------------------------------------
say "systemd: last inn på nytt"
systemctl daemon-reload

echo
say "Alt klart ✅"
cat <<INFO
Filer:
 - $ROOT_DIR/scripts/render-env.sh
 - $ROOT_DIR/deploy_cdn.sh
 - $ROOT_DIR/Makefile
 - /etc/systemd/system/elbatt-chatbot.service

Neste steg:
 1) Kjør 'make secrets' for å generere /etc/elbatt-chatbot.env fra Secret Manager.
 2) Sett S3‑nøkler i Secret Manager som 'AWS_ACCESS_KEY_ID' og 'AWS_SECRET_ACCESS_KEY'
    (Object Storage → S3 Credentials, ikke IAM), eller eksportér dem i env før deploy.
 3) Kjør 'make deploy-cdn' for å laste opp backend/static/embed.js til s3://$BUCKET/$KEY
    (bruker AWS CLI med endpoint https://s3.$REGION.scw.cloud).
    Sett SCW_SECRET_KEY i Actions/VM for å purge CDN automatisk.
 4) Rediger /etc/systemd/system/elbatt-chatbot.service og bytt ExecStart til din app,
    deretter:
       systemctl enable --now elbatt-chatbot
       systemctl status elbatt-chatbot --no-pager

Eksempler:
  make test-embed
  make test-preflight
  make test-post
INFO
