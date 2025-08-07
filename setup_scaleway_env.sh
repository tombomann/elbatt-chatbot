#!/bin/bash

echo "Setter opp Scaleway miljøvariabler..."
echo "====================================="

# Be om Scaleway API credentials
echo "Skriv inn din Scaleway API Access Key:"
read -s SCW_ACCESS_KEY
echo ""
echo "Skriv inn din Scaleway API Secret Key:"
read -s SCW_SECRET_KEY
echo ""
echo "Skriv inn din Scaleway Organization ID:"
read SCW_ORGANIZATION_ID

# Oppdater .env filen
cat > .env << ENV
# Scaleway Configuration
SCW_ACCESS_KEY=${SCW_ACCESS_KEY}
SCW_SECRET_KEY=${SCW_SECRET_KEY}
SCW_ORGANIZATION_ID=${SCW_ORGANIZATION_ID}

# OpenAI Configuration
OPENAI_API_KEY=${OPENAI_API_KEY}

# API Keys
VEGVESEN_API_KEY=${VEGVESEN_API_KEY}
LANGFLOW_API_KEY=${LANGFLOW_API_KEY}

# Application Settings
REDIS_URL=redis://redis:6379
ENVIRONMENT=production

# Scaleway specific
SCW_REGION=fr-par
SCW_ZONE=fr-par-1
ENV

echo "Miljøvariabler lagret i .env"
echo "Husk å kjøre 'chmod 600 .env' for sikkerhet"
chmod 600 .env
