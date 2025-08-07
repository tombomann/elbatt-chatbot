#!/bin/bash
# Health check med varsling

HEALTH_URL="http://localhost:8000/api/health"
WEBHOOK_URL="din_webhook_url_for_varsling"

if ! curl -f "$HEALTH_URL" > /dev/null 2>&1; then
    curl -X POST "$WEBHOOK_URL" -d '{"text": "❌ Elbatt Chatbot er nede!"}'
    exit 1
fi

curl -X POST "$WEBHOOK_URL" -d '{"text": "✅ Elbatt Chatbot er frisk"}'
