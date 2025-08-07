#!/bin/bash
set -e

echo "🚀 Starting deployment..."
git pull origin main
docker-compose down
docker-compose build --no-cache
docker-compose up -d

echo "⏳ Waiting for services to be healthy..."
sleep 10

if curl -f http://localhost:8000/api/health > /dev/null 2>&1; then
    echo "✅ Backend is healthy"
else
    echo "❌ Backend is not healthy"
    exit 1
fi

echo "🎉 Deployment completed successfully!"
