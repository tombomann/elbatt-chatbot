#!/usr/bin/env bash
set -euo pipefail
REGION="${REGION:-fr-par}"
echo "==> Aktive profiler:"
scw config profile list || true
echo "==> Nåværende profil:"
scw config get profile || true

echo "==> Namespaces i $REGION"
scw container namespace list region="$REGION" -o json | jq -r '.[] | [.id, .name, .region] | @tsv'

read -p "Skriv inn namespace-id du vil liste containere for: " NSID
echo "==> Containere i namespace $NSID"
scw container container list namespace-id="$NSID" region="$REGION" -o json \
  | jq -r '.[] | [.id, .name, .domain_name, .privacy] | @tsv'
