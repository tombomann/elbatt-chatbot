#!/bin/bash

echo "Fjerner backup-filer fra repoet..."

# Fjern backup-filer
git rm backend/main.py.backup 2>/dev/null || echo "backend/main.py.backup finnes ikke"
git rm backend/varta_service.py.backup 2>/dev/null || echo "backend/varta_service.py.backup finnes ikke"
git rm frontend/test-chatbot.html.backup 2>/dev/null || echo "frontend/test-chatbot.html.backup finnes ikke"

# Fjern generert kontekstfil
git rm glm-context.txt 2>/dev/null || echo "glm-context.txt finnes ikke"

echo "Commiter oppryddingen..."
git commit -m "chore: Fjern backup-filer og genererte filer fra repoet"

echo "Opprydding fullført"
