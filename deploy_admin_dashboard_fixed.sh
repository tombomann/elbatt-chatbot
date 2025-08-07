#!/bin/bash

echo "Deployer Admin Dashboard (Fixed Version)..."
echo "========================================="

# 1. Sjekk at nødvendige filer finnes
echo "1. Sjekker filstruktur..."
files=(
    "backend/Dockerfile.admin"
    "backend/admin_service.py"
    "admin-dashboard/Dockerfile"
    "admin-dashboard/nginx.conf"
    "docker-compose.admin.yml"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file finnes"
    else
        echo "✗ $file mangler"
    fi
done

echo ""
echo "2. Bygger Admin Dashboard..."
docker-compose -f docker-compose.admin.yml build --no-cache

# 3. Stopp eksisterende admin-dashboard containere hvis de kjører
echo "3. Stopper eksisterende admin-dashboard containere..."
docker-compose -f docker-compose.admin.yml down

# 4. Start admin dashboard
echo "4. Starter Admin Dashboard..."
docker-compose -f docker-compose.admin.yml up -d

echo "5. Venter på at tjenester starter..."
sleep 20

echo "6. Sjekker status..."
docker-compose -f docker-compose.admin.yml ps

echo ""
echo "7. Tester tilgjengelighet..."
echo "Tester frontend..."
frontend_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002 || echo "000")
if [ "$frontend_status" = "200" ]; then
    echo "✓ Frontend tilgjengelig (HTTP $frontend_status)"
else
    echo "✗ Frontend ikke tilgjengelig (HTTP $frontend_status)"
fi

echo "Tester backend..."
backend_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/api/health || echo "000")
if [ "$backend_status" = "200" ]; then
    echo "✓ Backend tilgjengelig (HTTP $backend_status)"
else
    echo "✗ Backend ikke tilgjengelig (HTTP $backend_status)"
fi

echo ""
echo "=== Admin Dashboard status ==="
if [ "$frontend_status" = "200" ] && [ "$backend_status" = "200" ]; then
    echo "✅ Admin Dashboard er fullt operasjonelt!"
    echo "Frontend: http://localhost:3002"
    echo "Backend API: http://localhost:8001"
    echo "Admin token: $(grep ADMIN_TOKEN .env | cut -d= -f2)"
else
    echo "❌ Admin Dashboard har problemer"
    echo "Sjekk logger med: docker-compose -f docker-compose.admin.yml logs"
fi

echo ""
echo "=== Viktig for produksjon: ==="
echo "1. Endre ADMIN_TOKEN i .env filen"
echo "2. Sett opp HTTPS med SSL-sertifikat"
echo "3. Konfigurer brannmur for porter 3002 og 8001"
echo "4. Sett opp logging og monitoring"
