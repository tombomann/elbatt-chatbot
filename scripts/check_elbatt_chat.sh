#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

HOST="chatbot.elbatt.no"
MYSTORE_URL="https://www.elbatt.no/"
EDGE="https://${HOST}"
S3="https://elbatt-cdn.s3.fr-par.scw.cloud/embed.js"

step() { echo -e "==> $*"; }

step "[1/5] Sjekker at siden svarer: ${MYSTORE_URL}"
code=$(curl -sk -o /dev/null -w "%{http_code}" "${MYSTORE_URL}")
[[ "$code" == "200" ]] && echo "✅ Siden svarte 200" || { echo "❌ HTTP ${code}"; exit 1; }

step "[2/5] Laster HTML og sjekker for 'Chat med oss' + script-tag"
html="$(curl -sk "${MYSTORE_URL}")"
echo "$html" | grep -Fq "Chat med oss" && echo "✅ Fant 'Chat med oss' i HTML" || echo "⚠️  Fant ikke 'Chat med oss'"
echo "$html" | grep -Fq 'https://chatbot.elbatt.no/embed.js' && echo "✅ Fant script-tag" || echo "⚠️  Mangler script-tag"

step "[3/5] Sjekker Render/Backend (valgfri referanse)"
curl -sI https://elbatt-chatbot.onrender.com/embed.js >/dev/null && echo "✅ Render-tjenesten svarer" || echo "⚠️  Render HEAD feilet"

step "[4/5] Sjekker edge /embed.js og /health"
curl -sI "${EDGE}/embed.js" | egrep -i '^(HTTP/|content-type|cache-control)' | sed 's/^/   /'
curl -sI "${EDGE}/health"   | head -n1 | sed 's/^/   /'

step "[5/5] Sammenligner ETag/Last-Modified mot S3"
echo "-- EDGE --"; curl -sI "${EDGE}/embed.js" | egrep -i '^(etag|last-modified|content-length|age):' | sed 's/^/   /'
echo "--  S3  --"; curl -sI "${S3}"            | egrep -i '^(etag|last-modified|content-length|age):' | sed 's/^/   /'

echo "✅ E2E-sjekk ferdig"
