#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE="${SERVICE:-api}"
PORT_TEST="${PORT_TEST:-8000}"

say(){ printf "\n==> %s\n" "$*"; }
note(){ printf "   -> %s\n" "$*"; }

# Finn compose
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "Finner ikke docker compose." >&2; exit 1
fi

say "1) Sikrer embed.js"
./fix-embed.sh

say "2) Lapper backend og Dockerfile"
./patch-embed-paths.sh

say "3) Bygger og starter"
$COMPOSE up -d --build

say "4) Vent til container kjører"
$COMPOSE ps
sleep 1

say "5) Verifiser i container"
$COMPOSE exec -T "${SERVICE}" sh -lc '
  (apk add --no-cache curl >/dev/null 2>&1) || (apt-get update -y >/dev/null 2>&1 && apt-get install -y curl >/dev/null 2>&1) || true
  echo "--- IN-CONTAINER ---"
  ls -l /app/static/embed.js || true
  curl -sI http://127.0.0.1:8000/health | sed -n "1p;/^content-type/I p" || true
  curl -sI http://127.0.0.1:8000/api/embed.js | sed -n "1p;/^content-type/I p;/^cache-control/I p"
  curl -sI http://127.0.0.1:8000/embed.js | sed -n "1p;/^content-type/I p;/^cache-control/I p" || true
'

say "6) Test fra vert (hvis port er eksponert)"
if ss -lnt | awk '{print $4}' | grep -q ":${PORT_TEST}$"; then
  curl -sI "http://localhost:${PORT_TEST}/api/embed.js" | sed -n "1p;/^content-type/I p;/^cache-control/I p"
else
  note "Port ${PORT_TEST} ser ikke ut til å være eksponert – hopper over."
fi

say "7) Ferdig. Klient‑tag:"
echo '<script src="https://chatbot.elbatt.no/api/embed.js" defer></script>'
