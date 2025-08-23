#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
#  Elbatt: embed.js via S3 + CDN (Scaleway)
#  Bruk:
#    bash embed-cdn.sh up         # lag bucket, last opp api/embed.js, (opprett CDN om mulig)
#    bash embed-cdn.sh upload     # last kun opp på nytt
#    bash embed-cdn.sh verify     # test origin/CDN og ekstern host
# =========================

# --- Konfig (endre ved behov) ---
REGION="${REGION:-fr-par}"
S3_ENDPOINT="${S3_ENDPOINT:-https://s3.${REGION}.scw.cloud}"

BUCKET="${BUCKET:-elbatt-embed}"                 # navnet på S3-bucket (må være globalt unikt i regionen)
OBJECT_LOCAL="${OBJECT_LOCAL:-backend/static/embed.js}"
OBJECT_KEY_API="${OBJECT_KEY_API:-api/embed.js}" # slik at /api/embed.js virker uten rewrite
OBJECT_KEY_ROOT="${OBJECT_KEY_ROOT:-embed.js}"   # valgfritt, som speil på /embed.js

HOST="${HOST:-https://chatbot.elbatt.no}"        # domenet du ønsker å serve på
CDN_NAME="${CDN_NAME:-elbatt-embed-cdn}"         # visningsnavn for CDN (hvis CLI-støtte finnes)

# --- Verktøy & helpers ---
need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Mangler kommando: $1"; exit 1; }; }
say()  { printf "\n==> %s\n" "$*"; }
note() { printf "   -> %s\n" "$*"; }

have_scw_cdn() { scw --help 2>/dev/null | grep -q 'cdn'; }  # grov deteksjon

s3() { aws s3 "$@" --endpoint-url "${S3_ENDPOINT}"; }
s3api() { aws s3api "$@" --endpoint-url "${S3_ENDPOINT}"; }

ensure_bucket() {
  say "Oppretter/verifiserer bucket: s3://${BUCKET}"
  if s3api head-bucket --bucket "${BUCKET}" >/dev/null 2>&1; then
    note "Bucket finnes allerede"
  else
    s3api create-bucket --bucket "${BUCKET}" --create-bucket-configuration LocationConstraint="${REGION}"
    note "Opprettet bucket ${BUCKET} i ${REGION}"
  fi
  # Gjør objekter lesbare (ACL public-read). (CDN kan også håndtere privat origin via Origin Access,
  # men her velger vi public for enkelhet.)
  s3api put-bucket-acl --bucket "${BUCKET}" --acl public-read
  note "Satt bucket-ACL til public-read (for enkel testing / CDN-origin)"
}

upload_object() {
  local key="$1"
  local src="$2"
  say "Laster opp ${src} → s3://${BUCKET}/${key}"
  s3 cp "${src}" "s3://${BUCKET}/${key}" \
    --content-type "application/javascript" \
    --cache-control "public, max-age=3600, immutable" \
    --acl public-read
  note "Lastet opp med Content-Type=application/javascript og Cache-Control=public, max-age=3600, immutable"
}

create_cdn_if_possible() {
  if ! have_scw_cdn; then
    say "Skipper CDN‑opprettelse (scw cdn‑kommandogrensesnitt ikke tilgjengelig)."
    echo "   -> Logg inn i Scaleway Console → CDN → Opprett 'Pull CDN' med origin: ${BUCKET}.s3.${REGION}.scw.cloud"
    echo "   -> Legg til Custom domain: chatbot.elbatt.no (CDN ordner TLS/Let's Encrypt)."
    echo "   -> Pek DNS CNAME: chatbot.elbatt.no → <cdn-endepunkt> (f.eks. XXXX.scalewaycdn.net)."
    return 0
  fi

  say "Oppretter/bruker CDN foran ${BUCKET}.s3.${REGION}.scw.cloud"
  # Finn eksisterende CDN service?
  CDN_ID="$(scw cdn service list -o json 2>/dev/null | jq -r ".[] | select(.name==\"${CDN_NAME}\") | .id" | head -n1 || true)"
  if [ -n "${CDN_ID}" ] && [ "${CDN_ID}" != "null" ]; then
    note "Fant eksisterende CDN: ${CDN_ID}"
  else
    CDN_ID="$(scw cdn service create name="${CDN_NAME}" origin="${BUCKET}.s3.${REGION}.scw.cloud" -o json | jq -r .id)"
    note "Opprettet CDN: ${CDN_ID}"
  fi

  # (Valgfritt) Slå på komprimering og caching hints (hvis støttet av CLI-versjonen)
  scw cdn service update "${CDN_ID}" enable-compression=true >/dev/null 2>&1 || true

  echo
  echo "ℹ️  Gå til Scaleway Console → CDN → ${CDN_NAME} og legg til Custom Domain:"
  echo "    - Custom domain: chatbot.elbatt.no  (CDN vil provisionere sertifikat)"
  echo "    - Kopiér 'Target' CNAME host (f.eks. XXXXX.scalewaycdn.net)"
  echo
  echo "📌 DNS hos Domeneshop:"
  echo "    chatbot.elbatt.no  CNAME  <CNAME fra CDN>"
  echo
  echo "Når DNS er aktivt, test:"
  echo "    curl -I ${HOST}/api/embed.js | sed -n '1p;/^content-type/I p;/^cache-control/I p'"
}

verify_origin() {
  say "Tester direkte mot origin (bucket endpoint)"
  # NB: Public endpoint-URL for objekt (virker pga public-read)
  for key in "${OBJECT_KEY_API}" "${OBJECT_KEY_ROOT}"; do
    curl -sI "https://${BUCKET}.s3.${REGION}.scw.cloud/${key}" | sed -n '1p;/^content-type/I p;/^cache-control/I p'
  done
}

verify_public() {
  say "Tester offentlig host: ${HOST}/api/embed.js"
  curl -sI "${HOST}/api/embed.js" | sed -n '1p;/^content-type/I p;/^cache-control/I p'
}

usage() {
  echo "Bruk:"
  echo "  $0 up       # lag bucket, last opp, (opprett CDN hvis mulig), vis DNS-instrukser"
  echo "  $0 upload   # last opp api/embed.js og embed.js på nytt"
  echo "  $0 verify   # test origin (bucket) og ekstern host"
}

# --- Entrypoint ---
cmd="${1:-}"
case "${cmd}" in
  up)
    need aws
    need jq
    need curl
    ensure_bucket
    [ -f "${OBJECT_LOCAL}" ] || { echo "❌ Finner ikke ${OBJECT_LOCAL}. Lag den først."; exit 1; }
    upload_object "${OBJECT_KEY_API}"  "${OBJECT_LOCAL}"
    upload_object "${OBJECT_KEY_ROOT}" "${OBJECT_LOCAL}"
    verify_origin
    create_cdn_if_possible
    echo
    echo "📎 Klient-tag trenger ingen endring:"
    echo "    <script src=\"${HOST}/api/embed.js\" defer></script>"
    ;;
  upload)
    need aws
    [ -f "${OBJECT_LOCAL}" ] || { echo "❌ Finner ikke ${OBJECT_LOCAL}"; exit 1; }
    upload_object "${OBJECT_KEY_API}"  "${OBJECT_LOCAL}"
    upload_object "${OBJECT_KEY_ROOT}" "${OBJECT_LOCAL}"
    ;;
  verify)
    need curl
    verify_origin || true
    verify_public || true
    ;;
  *)
    usage
    exit 1
    ;;
esac
