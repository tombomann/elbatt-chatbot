#!/bin/bash
echo "Sjekker status på Netlify/chatbot-domain..."

curl -s -I https://chatbot.elbatt.no/embed.js | grep HTTP
curl -s https://chatbot.elbatt.no/embed.js | head -20

echo "Sjekker backend FastAPI /ping..."
curl -s -I https://chatbot.elbatt.no/ping | grep HTTP
curl -s https://chatbot.elbatt.no/ping

echo "Sjekker Netlify custom domain status..."
dig +short chatbot.elbatt.no
