#!/usr/bin/env bash
set -Eeuo pipefail

# =======================
# Config (kan overstyres via env)
# =======================
BUCKET="${BUCKET:-elbatt-cdn}"
KEY="${KEY:-embed.js}"
SRC="${SRC:-/root/elbatt-chatbot/backend/static/embed.js}"
# Hvis du VET regionen, kan du sette ENDPOINT="https://s3.fr-par.scw.cloud"
ENDPOINT="${ENDPOINT:-}"
REGIONS=("fr-par" "nl-ams" "pl-waw")

# =======================
# Hjelpefunksjoner
# =======================
need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Mangler '$1'"; exit 1; }; }

err() { echo "❌ $*" >&2; exit 1; }

info() { echo "==> $*"; }

# =======================
# Forutsetninger
# =======================
need aws
need jq
need curl

# Last evt. inn hemmeligheter fra runtime-env (generert av `make secrets`)
if [ -f /etc/elbatt-chatbot.env ]; then
  # shellcheck disable=SC1091
  . /etc/elbatt-chatbot.env
fi

# S3-nøkler MÅ komme fra Object Storage → S3 Credentials (IKKE IAM)
: "${AWS_ACCESS_KEY_ID:?Sett AWS_ACCESS_KEY_ID (S3 Access Key) i env eller Secret Manager}"
: "${AWS_SECRET_ACCESS_KEY:?Sett AWS_SECRET_ACCESS_KEY (S3 Secret Key) i env eller Secret Manager}"

# IAM-secret (UUID) brukes bare for CDN purge (valgfritt)
SCW_SECRET_KEY="${SCW_SECRET_KEY:-}"                # UUID (fra IAM)
SCW_ACCESS_KEY="${SCW_ACCESS_KEY:-}"                # Ikke brukt av aws s3, kun ev. for egen debugging
SCW_DEFAULT_PROJECT_ID="${SCW_DEFAULT_PROJECT_ID:-}"# Ikke påkrevd for denne opplastingen

[ -f "$SRC" ] || err "Fant ikke kildefil: $SRC"

# =======================
# AWS CLI profil (isolerer mot andre profiler)
# =======================
mkdir -p ~/.aws
cat > ~/.aws/credentials <<EOF
[scaleway]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF

cat > ~/.aws/config <<'EOF'
[profile scaleway]
region = fr-par
output = json
EOF

export AWS_PROFILE=scaleway
export AWS_S3_FORCE_PATH_STYLE=true
export AWS_EC2_METADATA_DISABLED=true

# =======================
# Finn riktig endpoint (hvis ikke satt)
# =======================
REGION_FOUND=""
if [ -n "$ENDPOINT" ]; then
  REGION_FOUND="${ENDPOINT#https://s3.}"
  REGION_FOUND="${REGION_FOUND%.scw.cloud}"
  info "Bruker forhåndsdefinert ENDPOINT: $ENDPOINT (region: $REGION_FOUND)"
else
  info "Finner riktig endpoint for bucket '${BUCKET}'"
  for R in "${REGIONS[@]}"; do
    # NB: HeadBucket kan returnere JSON med BucketRegion, eller bare 0‑exit uten output
    OUT="$(aws s3api head-bucket --bucket "$BUCKET" --endpoint-url "https://s3.${R}.scw.cloud" 2>&1 || true)"
    if echo "$OUT" | grep -q '"BucketRegion"'; then
      REGION_FOUND="$(echo "$OUT" | jq -r '.BucketRegion')"
      ENDPOINT="https://s3.${REGION_FOUND}.scw.cloud"
      break
    fi
    if [ -z "$OUT" ]; then
      REGION_FOUND="$R"
      ENDPOINT="https://s3.${R}.scw.cloud"
      break
    fi
  done
fi

[ -n "${ENDPOINT:-}" ] || err "Fant ikke bucket '${BUCKET}' i fr-par/nl-ams/pl-waw med denne S3‑nøkkelen. Sjekk at nøkkelen har tilgang til bucketen og at navnet stemmer."
info "OK: bucket-region=${REGION_FOUND:-ukjent}, endpoint=${ENDPOINT}"

# =======================
# Opplasting
# =======================
info "Laster opp ${SRC} → s3://${BUCKET}/${KEY}"
aws s3 cp "$SRC" "s3://${BUCKET}/${KEY}" \
  --endpoint-url "$ENDPOINT" \
  --acl public-read \
  --content-type "application/javascript" \
  --cache-control "public, max-age=3600, immutable"

# =======================
# Purge Edge/Cache (valgfritt)
# =======================
if [ -n "$SCW_SECRET_KEY" ]; then
  info "Forsøker Edge/Cache purge"
  PURGE_URL="https://api.scaleway.com/object/v1/regions/${REGION_FOUND}/buckets/${BUCKET}/cache/purge"
  if curl -fsS -X POST \
       -H "Content-Type: application/json" \
       -H "X-Auth-Token: ${SCW_SECRET_KEY}" \
       -d "{\"paths\":[\"/${KEY}\"]}" \
       "$PURGE_URL" >/dev/null; then
    echo "   Purge OK"
  else
    echo "   ⚠️ Purge feilet (Edge/Cache kan være av). Filen er likevel lastet opp."
  fi
else
  echo "   (Hopper over purge – SCW_SECRET_KEY ikke satt)"
fi

echo "✅ Ferdig. Test:"
echo "   curl -I https://chatbot.elbatt.no/${KEY}"
