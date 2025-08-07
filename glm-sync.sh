#!/bin/bash
# Synkroniser med GLM-4.5 oppdateringer

echo "🤖 Syncing with GLM-4.5 updates..."

# 1. Sjekk for GLM-4.5 oppdateringer
echo "Checking for GLM-4.5 API updates..."
GLM_API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://api.openai.com/v1/models)

if [ "$GLM_API_STATUS" -eq 200 ]; then
    echo "✅ GLM-4.5 API is accessible"
    
    # 2. Sjekk for nye funksjoner
    echo "Checking for new GLM-4.5 features..."
    # Her kan du legge til logikk for å sjekke spesifikke funksjoner
    
    # 3. Oppdater applikasjonen om nødvendig
    echo "Updating application for GLM-4.5 compatibility..."
    git pull origin main
    docker-compose build --no-cache
    docker-compose up -d
    
    # 4. Test
    sleep 10
    if curl -f http://localhost:8000/api/health > /dev/null 2>&1; then
        echo "✅ GLM-4.5 sync successful!"
        
        # 5. Logg suksess
        echo "$(date): GLM-4.5 sync successful" >> /var/log/glm-sync.log
    else
        echo "❌ GLM-4.5 sync failed!"
        echo "$(date): GLM-4.5 sync failed" >> /var/log/glm-sync.log
    fi
else
    echo "❌ GLM-4.5 API not accessible"
    echo "$(date): GLM-4.5 API not accessible" >> /var/log/glm-sync.log
fi
