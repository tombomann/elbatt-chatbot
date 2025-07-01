#!/bin/bash

# === Deploy frontend (React + Nginx) med Docker automatisk ===
# Plasser denne fila i prosjekt-roten: /elbatt-chatbot/deploy_frontend.sh
# Kjør med: bash deploy_frontend.sh

set -e

cd "$(dirname "$0")" # Gå til rotmappe der scriptet ligger

echo "🔄 Stopper og fjerner eksisterende container..."
docker stop elbatt-frontend || true
docker rm elbatt-frontend || true

echo "🐳 Bygger nytt Docker-image for frontend..."
docker build -t elbatt-frontend:latest ./frontend

echo "🚀 Starter ny frontend-container på port 8080..."
docker run -d --name elbatt-frontend -p 8080:80 elbatt-frontend:latest

echo "✅ Frontend er bygget og kjører på http://localhost:8080"
