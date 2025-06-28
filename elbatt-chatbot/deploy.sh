#!/bin/bash
set -e

echo "Oppdaterer repo..."
cd /root/elbatt-chatbot
git pull origin main

echo "Laster ned backup fra S3..."
python3 /root/elbatt-chatbot/scripts/restore_from_s3.py

echo "Importer chatflow til Langflow..."
python3 /root/elbatt-chatbot/scripts/import_from_s3.py

echo "Starter backend og Langflow tjenester..."
systemctl restart elbatt-backend.service
systemctl restart langflow.service

echo "Deploy fullført."
