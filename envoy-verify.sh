#!/usr/bin/env bash
set -Eeuo pipefail
trap 'code=$?; line="${BASH_LINENO[0]:-${LINENO:-?}}"; echo; echo "✖ Feilet på linje ${line} (exit ${code})"; exit ${code}' ERR

HOST="${HOST:-https://chatbot.elbatt.no}"
echo "==> Test ${HOST}/api/embed.js"
curl -sI "${HOST}/api/embed.js" | sed -n '1p;/^content-type/I p;/^cache-control/I p'
