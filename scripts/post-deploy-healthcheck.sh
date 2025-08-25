#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-chatbot.elbatt.no}"
TIMEOUT="${TIMEOUT:-15}"

echo "▶ Health HTTPS"
code=$(curl -sS -m "$TIMEOUT" -o /tmp/health.json -w "%{http_code}" "https://${HOST}/api/health" || true)
test "$code" = "200" || { echo "Healthcheck feilet: HTTP $code"; cat /tmp/health.json || true; exit 1; }
jq -e '.ok == true' /tmp/health.json >/dev/null || { echo "Health .ok != true"; cat /tmp/health.json; exit 1; }

echo "▶ battery-by-plate SU18018"
code=$(curl -sS -m "$TIMEOUT" -o /tmp/plate.json -w "%{http_code}" "https://${HOST}/api/battery-by-plate?regnr=SU18018" || true)
test "$code" = "200" || { echo "Plate endpoint feilet: HTTP $code"; cat /tmp/plate.json || true; exit 1; }
jq -e '.ok == true' /tmp/plate.json >/dev/null || { echo "Plate .ok != true"; cat /tmp/plate.json; exit 1; }

echo "✅ OK"
