#!/usr/bin/env bash
set -Eeuo pipefail
HOST="${HOST:-https://chatbot.elbatt.no}"
echo "==> Test ${HOST}/api/embed.js"
curl -sI "${HOST}/api/embed.js" | sed -n '1p;/^content-type/I p;/^cache-control/I p'
