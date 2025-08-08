#!/bin/bash
set -e

echo "Sjekker mappestruktur..."
ls -la

# Logg inn på Scaleway Container Registry
echo "Logger inn på Scaleway Container Registry..."
scw registry login

# Bygg backend image
echo "Bygger backend image..."
docker build -t rg.fr-par.scw.cloud/elbatt/chatbot-backend:latest ./backend

# Bygg frontend image
echo "Bygger frontend image..."
docker build -t rg.fr-par.scw.cloud/elbatt/chatbot-frontend:latest ./frontend

# Bygg admin-backend image
echo "Bygger admin-backend image..."
docker build -t rg.fr-par.scw.cloud/elbatt/admin-backend:latest ./backend/admin

# Bygg admin-frontend image
echo "Bygger admin-frontend image..."
docker build -t rg.fr-par.scw.cloud/elbatt/admin-frontend:latest ./admin-frontend

# Push alle images
echo "Pusher images til Scaleway Registry..."
docker push rg.fr-par.scw.cloud/elbatt/chatbot-backend:latest
docker push rg.fr-par.scw.cloud/elbatt/chatbot-frontend:latest
docker push rg.fr-par.scw.cloud/elbatt/admin-backend:latest
docker push rg.fr-par.scw.cloud/elbatt/admin-frontend:latest

echo "Build og push fullført!"
