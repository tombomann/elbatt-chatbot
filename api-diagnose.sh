#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE="${SERVICE:-api}"
PORT_TEST="${PORT_TEST:-8000}"

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "Finner ikke docker compose." >&2; exit 1
fi

echo "==> Container‑sjekk"
$COMPOSE ps
echo "==> Logs (siste 80 linjer)"
$COMPOSE logs --tail=80 "${SERVICE}" || true

echo "==> In‑container tester"
$COMPOSE exec -T "${SERVICE}" sh -lc '
  (apk add --no-cache curl >/dev/null 2>&1) || (apt-get update -y >/dev/null 2>&1 && apt-get install -y curl >/dev/null 2>&1) || true
  curl -sS http://127.0.0.1:8000/health | head -c 200; echo
  curl -sI http://127.0.0.1:8000/api/embed.js | sed -n "1p;/^content-type/I p;/^cache-control/I p"
'

echo "==> Host‑tester (hvis port er eksponert)"
if ss -lnt | awk '{print $4}' | grep -q ":${PORT_TEST}$"; then
  curl -sI "http://localhost:${PORT_TEST}/api/embed.js" | sed -n "1p;/^content-type/I p;/^cache-control/I p"
else
  echo "   -> Port ${PORT_TEST} ikke eksponert – hopper over."
fi
