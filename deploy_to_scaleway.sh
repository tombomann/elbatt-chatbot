#!/bin/bash

echo "Deployer til Scaleway..."
echo "======================="

# 1. Bygg Docker images
echo "1. Bygger Docker images..."
docker-compose build

# 2. Tag images for Scaleway registry
echo "2. Tagger images for Scaleway..."
docker tag elbatt-chatbot_backend:latest rg.fr-par.scw.cloud/elbatt/backend:latest
docker tag elbatt-chatbot_frontend:latest rg.fr-par.scw.cloud/elbatt/frontend:latest

# 3. Push til Scaleway registry
echo "3. Pusher til Scaleway registry..."
docker push rg.fr-par.scw.cloud/elbatt/backend:latest
docker push rg.fr-par.scw.cloud/elbatt/frontend:latest

# 4. Oppdater docker-compose.yml for Scaleway
echo "4. Oppdaterer docker-compose.yml for Scaleway..."
cat > docker-compose.scaleway.yml << 'COMPOSE'
version: '3.8'
services:
  backend:
    image: rg.fr-par.scw.cloud/elbatt/backend:latest
    ports:
      - "8000:8000"
    env_file:
      - .env
    environment:
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
    restart: unless-stopped
    
  frontend:
    image: rg.fr-par.scw.cloud/elbatt/frontend:latest
    ports:
      - "3001:80"
    restart: unless-stopped
    
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  redis_data:
COMPOSE

echo "5. Kopierer filer til Scaleway server..."
# Erstatt med din Scaleway server IP
scp docker-compose.scaleway.yml .env root@DIN_SCALEWAY_IP:/opt/elbatt-chatbot/

echo "6. Deployer på Scaleway server..."
ssh root@DIN_SCALEWAY_IP << 'SSH'
cd /opt/elbatt-chatbot
docker-compose -f docker-compose.scaleway.yml down
docker-compose -f docker-compose.scaleway.yml pull
docker-compose -f docker-compose.scaleway.yml up -d
SSH

echo "Deployment fullført!"
