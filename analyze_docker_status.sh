#!/bin/bash

echo "=== Analyse av Docker Status på Scaleway ==="
echo "=========================================="

echo "1. Docker versjon:"
docker --version

echo ""
echo "2. Kjørende Docker containers:"
docker ps -a

echo ""
echo "3. Docker images:"
docker images | grep -E "(elbatt|admin|chatbot)"

echo ""
echo "4. Docker volumes:"
docker volume ls | grep elbatt

echo ""
echo "5. Docker networks:"
docker network ls | grep elbatt

echo ""
echo "6. System ressurser:"
docker system df

echo ""
echo "7. Sjekk for eksponerte porter:"
netstat -tlnp | grep -E "(8001|3002|6379)"

echo ""
echo "8. Sjekk logg for eventuelle feil:"
if docker ps | grep -q elbatt; then
    echo "Siste logger for elbatt containers:"
    docker logs --tail 20 $(docker ps | grep elbatt | awk '{print $1}' | head -1)
fi

echo ""
echo "9. Sjekk .env fil for nødvendige variabler:"
if [ -f .env ]; then
    echo "ADMIN_TOKEN satt: $(grep -q ADMIN_TOKEN .env && echo 'Ja' || echo 'Nei')"
    echo "OPENAI_API_KEY satt: $(grep -q OPENAI_API_KEY .env && echo 'Ja' || echo 'Nei')"
    echo "VEGVESEN_API_KEY satt: $(grep -q VEGVESEN_API_KEY .env && echo 'Ja' || echo 'Nei')"
else
    echo ".env fil ikke funnet"
fi

echo ""
echo "10. Sjekk filstruktur:"
echo "admin-dashboard mappe: $(test -d admin-dashboard && echo 'Eksisterer' || echo 'Mangler')"
echo "backend/admin_service.py: $(test -f backend/admin_service.py && echo 'Eksisterer' || echo 'Mangler')"
echo "docker-compose.admin.yml: $(test -f docker-compose.admin.yml && echo 'Eksisterer' || echo 'Mangler')"
echo "deploy_admin_dashboard.sh: $(test -f deploy_admin_dashboard.sh && echo 'Eksisterer' || echo 'Mangler')"

echo ""
echo "=== Analyse fullført ==="
