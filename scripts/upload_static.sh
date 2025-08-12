#!/usr/bin/env bash
set -euo pipefail
: "${SCW_ACCESS_KEY:?}"; : "${SCW_SECRET_KEY:?}"
: "${BUCKET:=elbatt-static}"  # sett ditt bucket-navn
pip install --quiet awscli
aws s3 sync frontend/public s3://$BUCKET \
  --endpoint-url https://s3.fr-par.scw.cloud --delete --acl public-read
echo "Lastet opp. Sett CNAME for CDN/Edge Services til bucket-endpointet."
