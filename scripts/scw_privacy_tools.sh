#!/usr/bin/env bash
set -euo pipefail
REGIONS=("fr-par" "nl-ams" "pl-waw")

list_all() {
  for r in "${REGIONS[@]}"; do
    scw container namespace list region="$r" -o json \
      | jq -r --arg r "$r" '.[] | "REGION=" + $r + "\tNS_ID=" + .id + "\tNS_NAME=" + .name'
    scw container container list region="$r" -o json \
      | jq -r --arg r "$r" '.[] | "REGION=" + $r + "\tCID=" + .id + "\tNAME=" + .name + "\tDOMAIN=" + (.domain_name//"") + "\tPRIVACY=" + .privacy'
  done
}

set_public() {
  local cid="$1" region="${2:-fr-par}"
  scw container container update "$cid" region="$region" privacy=public
  scw container container deploy "$cid" region="$region" --wait
  scw container container get "$cid" region="$region" -o json | jq -r '.domain_name, .privacy'
}

case "${1:-}" in
  list) list_all ;;
  public) set_public "${2:?CID}" "${3:-fr-par}" ;;
  *) echo "Bruk: $0 list | $0 public <CID> [REGION]"; exit 1 ;;
esac
