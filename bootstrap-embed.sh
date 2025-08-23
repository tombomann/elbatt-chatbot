#!/usr/bin/env bash
set -Eeuo pipefail

say(){ printf "\n==> %s\n" "$*"; }
note(){ printf "   -> %s\n" "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ Mangler kommando: $1"; exit 1; }; }

# --- 0) Konfig (endre ved behov) ---
REGION="${REGION:-fr-par}"
BUCKET="${BUCKET:-elbatt-embed}"                 # må være unikt i region
OBJECT_LOCAL="${OBJECT_LOCAL:-backend/static/embed.js}"
OBJECT_KEY_API="${OBJECT_KEY_API:-api/embed.js}"
OBJECT_KEY_ROOT="${OBJECT_KEY_ROOT:-embed.js}"
HOST="${HOST:-https://chatbot.elbatt.no}"

# --- 1) Installer avhengigheter (Ubuntu 24.04) ---
say "Installerer avhengigheter (jq, curl, unzip, AWS CLI v2 hvis mangler)"
apt-get update -y >/dev/null
apt-get install -y jq curl unzip >/dev/null

if ! command -v aws >/dev/null 2>&1; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install >/dev/null
  rm -rf /tmp/aws /tmp/awscliv2.zip
  note "AWS CLI v2 installert"
else
  note "AWS CLI v2 finnes allerede"
fi

# --- 2) Sjekk nøkkel-miljøvariabler ---
say "Sjekker Scaleway S3 nøkler i miljø (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY)"
: "${AWS_ACCESS_KEY_ID:?Sett AWS_ACCESS_KEY_ID (Scaleway Access Key)}"
: "${AWS_SECRET_ACCESS_KEY:?Sett AWS_SECRET_ACCESS_KEY (Scaleway Secret Key)}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${REGION}}"

# --- 3) Kjør CDN-oppsett: bucket + upload ---
say "Kjører embed-cdn.sh up (bucket + upload)"
[ -x ./embed-cdn.sh ] || { echo "❌ Finner ikke ./embed-cdn.sh (lagde du filen?)"; exit 1; }
./embed-cdn.sh up || { echo "❌ embed-cdn.sh up feilet"; exit 1; }

# --- 4) Verifiser origin (bucket) direkte ---
ORIGIN1="https://${BUCKET}.s3.${REGION}.scw.cloud/${OBJECT_KEY_API}"
ORIGIN2="https://${BUCKET}.s3.${REGION}.scw.cloud/${OBJECT_KEY_ROOT}"
say "Tester origin direkte (bør gi 200 OK + application/javascript)"
for u in "$ORIGIN1" "$ORIGIN2"; do
  echo "URL: $u"
  curl -sI "$u" | sed -n '1p;/^content-type/I p;/^cache-control/I p'
done

# --- 5) DNS-feilsøk for chatbot.elbatt.no (kan rettes senere) ---
say "DNS-sjekk for ${HOST} (kan feile hvis resolver er feil satt på denne maskinen)"
if command -v dig >/dev/null 2>&1; then
  dig +short "${HOST#https://}" || true
else
  note "dig ikke installert; installer med: apt-get install -y dnsutils"
fi

echo
echo "✅ Opplasting ferdig. Når CDN/CNAME er satt i DNS (Domeneshop) mot Scaleway CDN,"
echo "   tester du offentlig:"
echo "   curl -I ${HOST}/api/embed.js | sed -n '1p;/^content-type/I p;/^cache-control/I p'"
echo
echo "Hvis DNS-oppslag feiler *på denne serveren*, typiske quick-fix (midlertidig):"
echo "  resolvectl status | sed -n '1,120p'"
echo "  resolvectl dns ens2 1.1.1.1 9.9.9.9   # sett åpne resolvere på NIC"
echo "  resolvectl flush-caches"
echo
