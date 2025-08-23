#!/usr/bin/env bash
set -Eeuo pipefail

BUCKET="${BUCKET:-elbatt-cdn}"
REGION="${REGION:-fr-par}"
SRC="${SRC:-backend/static/embed.js}"
KEY="${KEY:-embed.js}"
CDN_URL="${CDN_URL:-https://chatbot.elbatt.no}"

say(){ printf "\n==> %s\n" "$*"; }

[ -f "$SRC" ] || { echo "❌ Fant ikke $SRC (kjør fra repo-rota eller sett SRC=)"; exit 1; }

# Foretrekk AWS CLI mot Scaleway S3 (med endpoint-url)
if command -v aws >/dev/null 2>&1; then
  : "${AWS_DEFAULT_REGION:=$REGION}"
  : "${AWS_S3_FORCE_PATH_STYLE:=true}"
  say "Laster opp med AWS CLI → s3://$BUCKET/$KEY"
  aws s3 cp "$SRC" "s3://$BUCKET/$KEY"     --endpoint-url "https://s3.$REGION.scw.cloud"     --acl public-read     --content-type "application/javascript"     --cache-control "public, max-age=3600, immutable"

# Fallback: ingen aws → si ifra
else
  echo "❌ AWS CLI ikke funnet. Installer eller bruk GitHub Actions-jobben."
  exit 1
fi

# Purge Scaleway Object‑CDN cache (hvis SCW_SECRET_KEY finnes)
if [ -n "${SCW_SECRET_KEY:-}" ]; then
  say "Purger CDN cache for /$KEY"
  curl -fsS -X POST \
    -H "Content-Type: application/json" \
    -H "X-Auth-Token: ${SCW_SECRET_KEY}" \
    -d "{\"paths\":[\"/$KEY\"]}" \
    "https://api.scaleway.com/object/v1/regions/$REGION/buckets/$BUCKET/cache/purge" >/dev/null     && echo "✅ Purge OK" || echo "⚠️ Purge feilet – cache utløper automatisk"
else
  echo "ℹ️ SCW_SECRET_KEY ikke satt – hopper over purge (cache utløper automatisk)"
fi

say "Ferdig. Test URL:"
echo "👉 ${CDN_URL}/${KEY}"
