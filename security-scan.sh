#!/bin/bash
# Sikkerhetsskanning av Docker images

echo "🔒 Scanning for security vulnerabilities..."

# Scan for sårbarheter
docker images | grep -v REPOSITORY | while read repo tag image_id; do
    echo "Scanning $repo:$tag..."
    docker scan "$image_id" || true
done

# Sjekk for oppdateringer
echo "📦 Checking for updates..."
docker-compose pull
