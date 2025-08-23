#!/usr/bin/env bash
set -euo pipefail

REG="rg.fr-par.scw.cloud/elbatt/elbatt/elbatt-chatbot"
TAG="prod-$(date +%Y%m%d%H%M)"

echo ">> Building $REG:$TAG"
docker build -t "$REG:$TAG" -f backend/Dockerfile .

echo ">> Pushing $REG:$TAG"
docker push "$REG:$TAG"

echo ">> Done. Set this image in Scaleway:"
echo "   $REG:$TAG"
