#!/bin/bash
echo "🔄 Updating Elbatt Chatbot..."

# Backup før oppdatering
docker-compose down
docker image prune -f

# Hent siste versjon
git pull origin main

# Bygg og start på nytt
docker-compose build --no-cache
docker-compose up -d

# Verifiser
sleep 10
curl -f http://localhost:8000/api/health && echo "✅ Update successful!"
