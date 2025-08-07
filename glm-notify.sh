#!/bin/bash
# Send varsling om GLM-4.5 oppdateringer

WEBHOOK_URL="din_webhook_url"

# Sjekk for GLM-4.5 oppdateringer
GLM_VERSION_CHECK=$(curl -s https://api.openai.com/v1/models | grep -o "gpt-4" | head -1)

if [ -n "$GLM_VERSION_CHECK" ]; then
    # Send varsel om oppdatering
    curl -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"🤖 GLM-4.5 oppdatering oppdaget! Sjekk kompatibilitet og oppdater applikasjonen.\"}"
    
    # Logg hendelsen
    echo "$(date): GLM-4.5 update detected" >> /var/log/glm-notifications.log
fi
