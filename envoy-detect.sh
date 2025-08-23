#!/usr/bin/env bash
set -Eeuo pipefail
trap 'code=$?; line="${BASH_LINENO[0]:-${LINENO:-?}}"; echo; echo "✖ Feilet på linje ${line} (exit ${code})"; exit ${code}' ERR
say(){ printf "\n==> %s\n" "$*"; }
note(){ printf "   -> %s\n" "$*"; }

ADMIN_URL="${ADMIN_URL:-http://127.0.0.1:9901}"
TARGET_HOST="${TARGET_HOST:-https://chatbot.elbatt.no}"
CHECK_PATH="${CHECK_PATH:-/api/embed.js}"

say "1) Forsøker Envoy admin på ${ADMIN_URL}"
if curl -fsS "${ADMIN_URL}/server_info" >/dev/null; then
  echo "OK: Envoy admin svarer."
else
  echo "Finner ikke Envoy admin på ${ADMIN_URL}."
  echo "Prøver å autodetektere container..."
  if docker ps --format '{{.ID}} {{.Image}} {{.Names}}' | grep -Ei 'envoy' >/dev/null 2>&1; then
    CID="$(docker ps --format '{{.ID}} {{.Names}}' | grep -Ei 'envoy' | head -n1 | awk '{print $1}')"
    echo "Fant Envoy container: ${CID}"
    echo "Prøver å port-forward admin (9901) via nsenter ikke støttet her – angi ADMIN_URL manuelt om nødvendig."
  else
    echo "Fant ingen Envoy container. Hvis Envoy kjører i en annen VM/pod, sett ADMIN_URL=http://IP:9901 og kjør igjen."
  fi
fi

say "2) Dump route-config (hvis admin er tilgjengelig)"
if curl -fsS "${ADMIN_URL}/config_dump" >/dev/null 2>&1; then
  curl -fsS "${ADMIN_URL}/config_dump" | jq -r '
    .configs[]
    | select(.["@type"] | tostring | contains("envoy.config.route.v3.RouteConfiguration"))
    | .route_config
    | {name, virtual_hosts: ( .virtual_hosts[] | {name, domains, routes: ( .routes[] | .match?.path? // .match?.prefix? )} ) }
  ' || true
else
  echo "Hopper over – ingen admin tilgang."
fi

say "3) Test mot offentlig host: ${TARGET_HOST}${CHECK_PATH}"
curl -sI "${TARGET_HOST}${CHECK_PATH}" | sed -n '1p;/^content-type/I p;/^cache-control/I p' || true
