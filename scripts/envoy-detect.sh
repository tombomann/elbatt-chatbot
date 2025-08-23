#!/usr/bin/env bash
set -Eeuo pipefail
trap 'code=$?; line="${BASH_LINENO[0]:-${LINENO:-?}}"; echo; echo "✖ Feilet på linje ${line} (exit ${code})"; exit ${code}' ERR
say(){ printf "\n==> %s\n" "$*"; }
ADMIN_URL="${ADMIN_URL:-http://127.0.0.1:9901}"
TARGET_HOST="${TARGET_HOST:-https://chatbot.elbatt.no}"
CHECK_PATH="${CHECK_PATH:-/api/embed.js}"

say "1) Envoy admin på ${ADMIN_URL}"
if curl -fsS "${ADMIN_URL}/server_info" >/dev/null; then
  echo "OK: Envoy admin svarer."
else
  echo "Ingen admin på ${ADMIN_URL}. Sjekker container…"
  if docker ps --format '{{.ID}} {{.Image}} {{.Names}}' | grep -Ei 'envoy' >/dev/null 2>&1; then
    docker ps --format '  -> {{.Names}} ({{.Image}})'
  else
    echo "Ingen Envoy container her – ruting sannsynligvis ekstern (f.eks. Mystore)."
  fi
fi

say "2) Offentlig test: ${TARGET_HOST}${CHECK_PATH}"
curl -sI "${TARGET_HOST}${CHECK_PATH}" | sed -n '1p;/^content-type/I p;/^cache-control/I p'
