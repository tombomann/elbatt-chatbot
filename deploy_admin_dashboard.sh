#!/bin/bash

echo "Deployer Admin Dashboard..."
echo "========================="

# 1. Bygg admin dashboard
echo "1. Bygger Admin Dashboard..."
docker-compose -f docker-compose.admin.yml build

# 2. Stopp eksisterende containere hvis de kjører
echo "2. Stopper eksisterende containere..."
docker-compose -f docker-compose.admin.yml down

# 3. Start admin dashboard
echo "3. Starter Admin Dashboard..."
docker-compose -f docker-compose.admin.yml up -d

echo "4. Venter på at tjenester starter..."
sleep 15

echo "5. Sjekker status..."
docker-compose -f docker-compose.admin.yml ps

echo ""
echo "6. Tester tilgjengelighet..."
echo "Tester frontend..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3002 || echo "Frontend ikke tilgjengelig"

echo "Tester backend..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/api/health || echo "Backend ikke tilgjengelig"

echo ""
echo "=== Admin Dashboard er nå tilgjengelig på: ==="
echo "Frontend: http://localhost:3002"
echo "Backend API: http://localhost:8001"
echo "Admin token: admin-secret"
echo ""
echo "=== Viktig for produksjon: ==="
echo "1. Endre ADMIN_TOKEN i .env filen"
echo "2. Sett opp HTTPS med SSL-sertifikat"
echo "3. Konfigurer brannmur for porter 3002 og 8001"
echo "4. Sett opp logging og monitoring"
