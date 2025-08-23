#!/usr/bin/env bash
set -Eeuo pipefail

ENVOY_YAML="${ENVOY_YAML:-/etc/envoy/envoy.yaml}"
LISTENER_NAME="${LISTENER_NAME:-listener_http}"
VHOST_NAME="${VHOST_NAME:-elbatt_vhost}"
CLUSTER_NAME="${CLUSTER_NAME:-elbatt_api}"

say(){ printf "\n==> %s\n" "$*"; }
note(){ printf "   -> %s\n" "$*"; }

[ -f "${ENVOY_YAML}" ] || { echo "Finner ikke ${ENVOY_YAML}" >&2; exit 1; }

route_api='
name: embed_api
match: { path: "/api/embed.js" }
route:
  cluster: '"${CLUSTER_NAME}"'
  timeout: 15s
  retry_policy: { retry_on: "5xx", num_retries: 2 }
response_headers_to_add:
  - header: { key: "Cache-Control", value: "public, max-age=3600, immutable" }
'
route_root='
name: embed_root
match: { path: "/embed.js" }
route:
  cluster: '"${CLUSTER_NAME}"'
  timeout: 15s
'

route_head='
name: health_head
match:
  path: "/health"
  headers:
    - name: ":method"
      exact_match: "HEAD"
direct_response:
  status: 200
'

backup="${ENVOY_YAML}.bak.$(date +%Y%m%d%H%M%S)"
cp -a "${ENVOY_YAML}" "${backup}"
note "Backup: ${backup}"

if command -v yq >/dev/null 2>&1; then
  say "Bruker yq for å legge til ruter"
  # Sett inn tre ruter øverst i routes[] for valgt vhost
  yq -i '
    (.static_resources.listeners[] | select(.name=="'"${LISTENER_NAME}"'") |
     .filter_chains[].filters[] |
     select(.name=="envoy.filters.network.http_connection_manager") |
     .typed_config.route_config.virtual_hosts[] | select(.name=="'"${VHOST_NAME}"'") |
     .routes) |= ([env(route_head), env(route_api), env(route_root)] + .)
  ' "${ENVOY_YAML}"
  note "Lagt til /health (HEAD), /api/embed.js (med cache) og /embed.js"
else
  say "yq ikke funnet – lager unified diff som kan applies med 'patch -p0'"
  tmpdiff="$(mktemp)"
  cat > "${tmpdiff}" <<'DIFF'
--- envoy.yaml
+++ envoy.yaml
@@
                 virtual_hosts:
                   - name: elbatt_vhost
                     domains: ["chatbot.elbatt.no", "chatbot.elbatt.no:80"]
                     routes:
+                      - match:
+                          path: "/health"
+                          headers:
+                            - name: ":method"
+                              exact_match: "HEAD"
+                        direct_response:
+                          status: 200
+                      - match: { path: "/api/embed.js" }
+                        route:
+                          cluster: elbatt_api
+                          timeout: 15s
+                          retry_policy: { retry_on: "5xx", num_retries: 2 }
+                        response_headers_to_add:
+                          - header: { key: "Cache-Control", value: "public, max-age=3600, immutable" }
+                      - match: { path: "/embed.js" }
+                        route:
+                          cluster: elbatt_api
+                          timeout: 15s
DIFF
  echo "Unified diff skrevet til: ${tmpdiff}"
  echo "Forsøk å apply:"
  (cd "$(dirname "${ENVOY_YAML}")" && patch -p0 < "${tmpdiff}") || {
    echo "Kunne ikke apply diff automatisk. Åpne diffen og gjør endringen manuelt." >&2
    exit 1
  }
fi

say "Validér Envoy (hvis binæren er tilgjengelig)"
if command -v envoy >/dev/null 2>&1; then
  envoy --mode validate -c "${ENVOY_YAML}"
else
  note "envoy ikke i PATH – hopper over validering"
fi

say "Ferdig. Test etter reload:"
echo "curl -I https://chatbot.elbatt.no/api/embed.js"
