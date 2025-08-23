#!/usr/bin/env bash
set -Eeuo pipefail
say(){ printf "\n==> %s\n" "$*"; }

HOST="${HOST:-https://chatbot.elbatt.no}"

say "Lokal container-test"
curl -sI http://127.0.0.1:8000/api/embed.js | sed -n '1p;/^content-type/I p;/^cache-control/I p' || true

say "Offentlig test mot ${HOST}/api/embed.js"
curl -sI "${HOST}/api/embed.js" | sed -n '1p;/^content-type/I p;/^cache-control/I p' || true

say "Sjekk om Envoy finnes lokalt"
if docker ps | grep -Ei 'envoy' >/dev/null 2>&1; then
  echo "-> Envoy-container finnes, men du må editere dens envoy.yaml eller admin xDS."
else
  echo "-> Ingen Envoy/container her. Ruting ligger hos ekstern proxy/leverandør (f.eks. Mystore)."
fi

echo
echo "Konklusjon: Backend svarer 200 lokalt, men 404 eksternt."
echo "Åpne en rute i proxyen til /api/embed.js => elbatt_api (samme cluster/upstream som /api/*)."
