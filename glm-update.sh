#!/bin/bash
# Spesialscript for å holde GLM-4.5 oppdatert

echo "🤖 Updating for GLM-4.5 compatibility..."

# 1. Sjekk om det er oppdateringer for GLM-4.5
echo "Checking for GLM-4.5 updates..."
git fetch origin

# 2. Sjekk om det er GLM-4.5 spesifikke endringer
if git log HEAD..origin/main --oneline | grep -i "glm"; then
    echo "GLM-4.5 updates found. Pulling changes..."
    git pull origin main
    
    # 3. Bygg og start på nytt
    docker-compose build --no-cache
    docker-compose up -d
    
    # 4. Verifiser
    sleep 10
    if curl -f http://localhost:8000/api/health > /dev/null 2>&1; then
        echo "✅ GLM-4.5 update successful!"
        
        # 5. Send varsel
        curl -X POST "din_webhook_url" -d '{"text": "✅ GLM-4.5 oppdatering fullført!"}'
    else
        echo "❌ GLM-4.5 update failed!"
        curl -X POST "din_webhook_url" -d '{"text": "❌ GLM-4.5 oppdatering feilet!"}'
    fi
else
    echo "No GLM-4.5 updates found."
fi
