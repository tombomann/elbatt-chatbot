#!/bin/bash
# Oppdater .env for alle tjenester og restart dem

ENV_SOURCE="/root/elbatt-chatbot/.env"
ENV_TARGET1="/root/langflow/.env"
ENV_TARGET2="/root/elbatt-chatbot/.env"

cp "$ENV_SOURCE" "$ENV_TARGET1"
cp "$ENV_SOURCE" "$ENV_TARGET2"

echo "Restarting services..."
systemctl restart langflow
systemctl restart caddy
systemctl restart chatbot  # hvis chatbot kjører som service
echo "Done!"
