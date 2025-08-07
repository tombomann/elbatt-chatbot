#!/bin/bash

echo "Deployer Admin Dashboard (Final Fix)..."
echo "====================================="

# 1. Stopp alle eksisterende containere
echo "1. Stopper eksisterende containere..."
docker-compose -f docker-compose.admin.yml down
docker-compose down 2>/dev/null || true

# 2. Sjekk port 8001
echo "2. Sjekker port 8001..."
if netstat -tlnp | grep -q ":8001 "; then
    echo "Port 8001 er fortsatt i bruk. Forsøker å frigjøre..."
    # Finn og stopp prosessen som bruker port 8001
    pid=$(netstat -tlnp 2>/dev/null | grep ":8001 " | awk '{print $7}' | cut -d'/' -f1)
    if [ ! -z "$pid" ]; then
        echo "Stopper prosess $pid som bruker port 8001"
        kill -9 $pid 2>/dev/null || true
    fi
    sleep 2
fi

# 3. Start admin dashboard
echo "3. Starter Admin Dashboard..."
docker-compose -f docker-compose.admin.yml up -d

echo ""
echo "4. Venter på at tjenester starter..."
sleep 20

echo ""
echo "5. Sjekker status..."
docker-compose -f docker-compose.admin.yml ps

echo ""
echo "6. Tester tilgjengelighet..."
echo "Tester frontend..."
frontend_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002 || echo "000")
if [ "$frontend_status" = "200" ]; then
    echo "✓ Frontend tilgjengelig (HTTP $frontend_status)"
else
    echo "✗ Frontend ikke tilgjengelig (HTTP $frontend_status)"
fi

echo "Tester backend..."
backend_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8002/api/health || echo "000")
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
    echo "Backend API: http://localhost:8002"
    echo "Admin token: $(grep ADMIN_TOKEN .env | cut -d= -f2)"
else
    echo "❌ Admin Dashboard har problemer"
    echo "Sjekk logger med: docker-compose -f docker-compose.admin.yml logs"
    echo ""
    echo "Feilsøkingstips:"
    echo "1. Sjekk porter: netstat -tlnp | grep -E '(3002|8002)'"
    echo "2. Sjekk containere: docker-compose -f docker-compose.admin.yml ps"
    echo "3. Sjekk logger: docker-compose -f docker-compose.admin.yml logs"
fi

echo ""
echo "7. Oppretter statisk backup..."
./create_static_admin.sh
