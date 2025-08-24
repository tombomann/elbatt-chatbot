#!/usr/bin/env bash
set -euo pipefail

URL="${HEALTH_URL:-https://chatbot.elbatt.no/health}"
TRIES=10
SLEEP=3

echo "Sjekker helse på: $URL"
for i in $(seq 1 $TRIES); do
  if curl -fsS --max-time 5 "$URL" >/dev/null; then
    echo "✅ Health OK"
    exit 0
  fi
  echo "Vent og prøv på nytt ($i/$TRIES)…"
  sleep "$SLEEP"
done

echo "❌ Healthcheck feilet for $URL"
exit 1
