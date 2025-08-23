#!/usr/bin/env bash
set -Eeuo pipefail
trap 'code=$?; line="${BASH_LINENO[0]:-${LINENO:-?}}"; echo; echo "✖ Feilet på linje ${line} (exit ${code})"; exit ${code}' ERR
say(){ printf "\n==> %s\n" "$*"; }
note(){ printf "   -> %s\n" "$*"; }

ENVOY_YAML="${ENVOY_YAML:-/etc/envoy/envoy.yaml}"
LISTENER_NAME="${LISTENER_NAME:-listener_http}"
VHOST_NAME="${VHOST_NAME:-elbatt_vhost}"
CLUSTER_NAME="${CLUSTER_NAME:-elbatt_api}"

# Små utils
have(){ command -v "$1" >/dev/null 2>&1; }

say "1) Finn envoy.yaml"
if [ ! -f "${ENVOY_YAML}" ]; then
  for cand in ./envoy.yaml ./ops/envoy/envoy.yaml ./deploy/envoy.yaml /usr/local/etc/envoy.yaml /opt/envoy/envoy.yaml /etc/envoy/envoy.yaml; do
    [ -f "$cand" ] && ENVOY_YAML="$cand" && break
  done
fi
[ -f "${ENVOY_YAML}" ] || { echo "Finner ikke envoy.yaml. Sett ENVOY_YAML=/sti/til/envoy.yaml"; exit 1; }
note "Bruker ${ENVOY_YAML}"

PATCH_API="$(cat <<YAML
- match:
    path: "/api/embed.js"
  route:
    cluster: ${CLUSTER_NAME}
    timeout: 15s
    retry_policy:
      retry_on: "5xx"
      num_retries: 2
    response_headers_to_add:
      - header:
          key: "Cache-Control"
          value: "public, max-age=3600, immutable"
YAML
)"

PATCH_ROOT="$(cat <<YAML
- match:
    path: "/embed.js"
  route:
    cluster: ${CLUSTER_NAME}
    timeout: 15s
YAML
)"

say "2) Prøver automatisk patch med yq (hvis tilgjengelig)"
if have yq; then
  cp -a "${ENVOY_YAML}" "${ENVOY_YAML}.bak.$(date +%s)"
  set +e
  yq -i '
    (.static_resources.listeners[] |
      select(.name=="'"${LISTENER_NAME}"'") |
      .filter_chains[].filters[].typed_config.["route_config"].virtual_hosts[] |
      select(.name=="'"${VHOST_NAME}"'") |
      .routes
    ) += '"${PATCH_API}"' |
    (.static_resources.listeners[] |
      select(.name=="'"${LISTENER_NAME}"'") |
      .filter_chains[].filters[].typed_config.["route_config"].virtual_hosts[] |
      select(.name=="'"${VHOST_NAME}"'") |
      .routes
    ) += '"${PATCH_ROOT}"'
  ' "${ENVOY_YAML}"
  rc=$?
  set -e
  if [ $rc -eq 0 ]; then
    note "yq‑patch OK. Husk å restarte Envoy eller deploy på nytt."
    exit 0
  else
    echo "yq‑patch feilet (struktur kan avvike). Viser manuell patch under."
  fi
else
  echo "yq ikke installert – genererer manuell patch."
fi

say "3) Manuell patch – lim inn under virtual_host '${VHOST_NAME}' → routes:"
cat <<'INFO'
-------------------------------- CUT HERE --------------------------------
# Legg disse to routes inn i:
# static_resources:
#   listeners:
#     - name: <LISTENER_NAME>
#       filter_chains:
#         - filters:
#             - name: envoy.filters.network.http_connection_manager
#               typed_config:
#                 @type: type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
#                 route_config:
#                   name: local_route
#                   virtual_hosts:
#                     - name: <VHOST_NAME>
#                       routes:
#                         # ↴ LIM INN HER
- match:
    path: "/api/embed.js"
  route:
    cluster: CLUSTER_PLACEHOLDER
    timeout: 15s
    retry_policy:
      retry_on: "5xx"
      num_retries: 2
    response_headers_to_add:
      - header:
          key: "Cache-Control"
          value: "public, max-age=3600, immutable"

- match:
    path: "/embed.js"
  route:
    cluster: CLUSTER_PLACEHOLDER
    timeout: 15s
# Bytt CLUSTER_PLACEHOLDER til: '"${CLUSTER_NAME}"'
# Listener: '"${LISTENER_NAME}"'  –  VirtualHost: '"${VHOST_NAME}"'
-------------------------------- CUT HERE --------------------------------
INFO

echo
echo "Når patch er lagt inn, restart Envoy (f.eks. systemctl restart envoy, docker restart <container>),"
echo "og verifiser med: curl -I https://chatbot.elbatt.no/api/embed.js"
