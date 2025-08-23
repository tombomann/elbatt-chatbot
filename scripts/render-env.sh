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
