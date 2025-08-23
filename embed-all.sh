#!/usr/bin/env bash
set -Eeuo pipefail

say(){ printf "\n==> %s\n" "$*"; }
note(){ printf "   -> %s\n" "$*"; }
warn(){ printf "⚠ %s\n" "$*"; }
die(){ echo "❌ $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Mangler kommando: $1"; }

trap 'code=$?; line="${BASH_LINENO[0]:-${LINENO:-?}}"; echo; echo "✖ Feilet på linje ${line} (exit ${code})"; exit ${code}' ERR

# ---------- Persist config ----------
ENV_FILE=".env.embed"

# Defaults (kan overskrives via env eller .env.embed)
REGION="${REGION:-fr-par}"
BUCKET="${BUCKET:-elbatt-embed}"
HOST="${HOST:-https://chatbot.elbatt.no}"

OBJECT_LOCAL="${OBJECT_LOCAL:-backend/static/embed.js}"
KEY_API="${KEY_API:-api/embed.js}"
KEY_ROOT="${KEY_ROOT:-embed.js}"

CACHE_CTL="${CACHE_CTL:-public, max-age=3600, immutable}"
CONTENT_TYPE="${CONTENT_TYPE:-application/javascript}"

S3_ENDPOINT="https://s3.${REGION}.scw.cloud"
# Scaleway S3 quirks:
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${REGION}}"
export AWS_S3_FORCE_PATH_STYLE="${AWS_S3_FORCE_PATH_STYLE:-true}"

load_env() { [ -f "${ENV_FILE}" ] && . "${ENV_FILE}"; }

save_env() {
  cat > "${ENV_FILE}" <<EOF
REGION="${REGION}"
BUCKET="${BUCKET}"
HOST="${HOST}"
OBJECT_LOCAL="${OBJECT_LOCAL}"
KEY_API="${KEY_API}"
KEY_ROOT="${KEY_ROOT}"
CACHE_CTL="${CACHE_CTL}"
CONTENT_TYPE="${CONTENT_TYPE}"
S3_ENDPOINT="${S3_ENDPOINT}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}"
AWS_S3_FORCE_PATH_STYLE="${AWS_S3_FORCE_PATH_STYLE}"
EOF
}

aws_wrap(){ aws "$@" --endpoint-url "${S3_ENDPOINT}"; }
s3(){ aws_wrap s3 "$@"; }
s3api(){ aws_wrap s3api "$@"; }

check_bins() {
  say "Installerer/validerer avhengigheter (jq, curl, unzip, AWS CLI v2, scw)"
  apt-get update -y >/dev/null
  apt-get install -y jq curl unzip >/dev/null
  if ! command -v aws >/dev/null 2>&1; then
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install >/dev/null
  fi
  if ! command -v scw >/dev/null 2>&1; then
    curl -fsSL https://github.com/scaleway/scaleway-cli/releases/latest/download/scw-$(uname -s)-$(uname -m) -o /usr/local/bin/scw
    chmod +x /usr/local/bin/scw
  fi
}

check_keys() {
  say "Sjekker Scaleway S3 nøkler (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY)"
  : "${AWS_ACCESS_KEY_ID:?Sett AWS_ACCESS_KEY_ID (Scaleway Project API key med Object Storage)}"
  : "${AWS_SECRET_ACCESS_KEY:?Sett AWS_SECRET_ACCESS_KEY}"
  note "Miljø ok"
}

aws_diag() {
  say "AWS/Scaleway diagnostikk"
  echo "endpoint : ${S3_ENDPOINT}"
  echo "region   : ${AWS_DEFAULT_REGION}"
  echo "pathstyle: ${AWS_S3_FORCE_PATH_STYLE}"
  set +e
  aws_wrap s3api list-buckets >/tmp/buckets.json 2>/tmp/buckets.err
  rc=$?
  set -e
  if [ $rc -ne 0 ]; then
    warn "list-buckets feilet:"
    sed -n '1,80p' /tmp/buckets.err
    die $'Dette er nesten alltid feil prosjekt/nøkler ELLER nøkler uten Object Storage-tilgang.\nLøsning: Lag en *Project API key* i riktig prosjekt med Object Storage aktivert.'
  fi
  note "list-buckets OK"
}

ensure_bucket() {
  say "Oppretter/verifiserer bucket: s3://${BUCKET}"
  if s3api head-bucket --bucket "${BUCKET}" >/dev/null 2>&1; then
    note "Bucket finnes allerede"
    return
  fi

  set +e
  s3api create-bucket --bucket "${BUCKET}" \
    --create-bucket-configuration "LocationConstraint=${REGION}" >/tmp/create.out 2>/tmp/create.err
  rc=$?
  set -e
  if [ $rc -ne 0 ]; then
    if grep -qi 'Forbidden' /tmp/create.err; then
      warn "403 Forbidden ved opprettelse – prøver unikt navn (kollisjon eller manglende tillatelser)."
      BUCKET="${BUCKET}-$(date +%s)"
      save_env
      s3api create-bucket --bucket "${BUCKET}" \
        --create-bucket-configuration "LocationConstraint=${REGION}"
      note "Opprettet bucket ${BUCKET}"
    else
      warn "create-bucket feilet:"
      sed -n '1,80p' /tmp/create.err
      die "Stoppet."
    fi
  else
    note "Opprettet bucket ${BUCKET}"
  fi

  # Public read for enkel CDN/origin
  s3api put-bucket-acl --bucket "${BUCKET}" --acl public-read || warn "ACL public-read feilet (kan være IAM/policy)."
}

upload_objects() {
  say "Laster opp embed.js → s3://${BUCKET}/{${KEY_API},${KEY_ROOT}}"
  [ -f "${OBJECT_LOCAL}" ] || die "Finner ikke ${OBJECT_LOCAL}"
  s3 cp "${OBJECT_LOCAL}" "s3://${BUCKET}/${KEY_API}" \
    --acl public-read --cache-control "${CACHE_CTL}" --content-type "${CONTENT_TYPE}"
  s3 cp "${OBJECT_LOCAL}" "s3://${BUCKET}/${KEY_ROOT}" \
    --acl public-read --cache-control "${CACHE_CTL}" --content-type "${CONTENT_TYPE}"
  note "Opplasting OK"
}

verify_origin() {
  say "Tester origin (bør gi 200 OK + application/javascript)"
  for u in \
    "https://${BUCKET}.s3.${REGION}.scw.cloud/${KEY_API}" \
    "https://${BUCKET}.s3.${REGION}.scw.cloud/${KEY_ROOT}"
  do
    echo "URL: $u"
    curl -sI "$u" | sed -n '1p;/^content-type/I p;/^cache-control/I p'
  done
}

print_dns() {
  say "DNS-instruks (CNAME)"
  cat <<TXT
chatbot.elbatt.no   CNAME   <CDN_TARGET_DU_FÅR_NEDENFOR>
(vent på TTL, deretter skal https://chatbot.elbatt.no/api/embed.js svare 200 OK)

Mid­lertidig kan du teste direkte origin:
  https://${BUCKET}.s3.${REGION}.scw.cloud/${KEY_API}
TXT
}

cdn_create() {
  say "CDN-oppsett (Scaleway)"
  # ===> LEGG INN DEN FERDIGE KOMMANDOEN DU LOVTE HER (vi kjører den for deg)
  # Eksempel (PLACEHOLDER! erstatt med korrekt):
  # scw cdn domain create domain.name="${HOST#https://}" origin="${BUCKET}.s3.${REGION}.scw.cloud" tls.letsEncrypt.commonName="${HOST#https://}"
  #
  # Etterpå bør vi kunne hente CNAME-target slik:
  if scw cdn domain list 2>/dev/null | grep -q "${HOST#https://}"; then
    scw cdn domain get "${HOST#https://}" -o json | jq -r '
      .dns_records[]?.name? // .domain?.name?, .dns_records[]?.value? // empty
    ' | paste - - | sed 's/\t/ → /'
    note "Oppslag over viser <ditt host> → <CNAME-target>"
  else
    warn "Fant ikke CDN‑domenet via scw (kjør din eksakte opprettelseskommando og prøv igjen)."
  fi
}

verify_public() {
  say "Tester offentlig host: ${HOST}/api/embed.js"
  curl -sI "${HOST}/api/embed.js" | sed -n '1p;/^content-type/I p;/^cache-control/I p' || true
}

init() {
  check_bins
  save_env
}

up() {
  load_env
  check_keys
  aws_diag
  ensure_bucket
  upload_objects
  save_env
}

upload() {
  load_env
  check_keys
  upload_objects
}

verify() {
  load_env
  verify_origin
  verify_public
}

dns() {
  load_env
  print_dns
}

cdn() {
  load_env
  need scw
  cdn_create
}

all() {
  init
  up
  verify
  dns
}

case "${1:-}" in
  init|up|upload|verify|dns|cdn|all) "$1" ;;
  *) echo "Bruk: $0 {init|up|upload|verify|dns|cdn|all}"; exit 1 ;;
esac
