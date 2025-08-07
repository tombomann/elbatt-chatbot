#!/bin/bash

echo "=== GLM-4.5 Context Sync ==="
echo "Prosjekt: elbatt-chatbot"
echo "Siste commit: $(git log -1 --pretty=format:'%h - %s (%cr)')"
echo ""

# Generer session summary
./scripts/generate_session_summary.sh

echo "=== Implementerte Funksjoner ==="
if [ -f "GLM-4.5-FEATURES.md" ]; then
    grep "✓" GLM-4.5-FEATURES.md | head -10
else
    echo "GLM-4.5-FEATURES.md ikke funnet"
fi

echo ""
echo "=== Nylige Endringer ==="
git log --oneline -5

echo ""
echo "=== Session Summary ==="
if [ -f "session_summary.json" ]; then
    python3 -c "
import json
with open('session_summary.json') as f:
    data = json.load(f)
    print(f'Sist oppdatert: {data.get(\"timestamp\", \"Ukjent\")}')
    print(f'Antall funksjoner: {len(data.get(\"features\", []))}')
    print(f'TODO items: {len(data.get(\"todo_items\", []))}')
    print(f'API endpoints: {len(data.get(\"api_endpoints\", []))}')
    "
else
    echo "session_summary.json ikke funnet"
fi

echo ""
echo "=== Kontekst for GLM-4.5 ==="
cat > glm-context.txt << CONTEXT_EOF
# GLM-4.5 Kontekst for elbatt-chatbot

## Prosjektstatus
$(git log -1 --pretty=format:'%h - %s (%cr)')

## Viktige Filer
- backend/main.py: Hoved-API med FastAPI
- backend/openai_service.py: GLM-4.5 integrasjon
- docker-compose.yml: Container-oppsett
- GLM-4.5-FEATURES.md: Funksjonsoversikt

## Nåværende Faser
$(if [ -f "session_summary.json" ]; then
    python3 -c "
import json
with open('session_summary.json') as f:
    data = json.load(f)
    print(f'Timestamp: {data.get(\"timestamp\", \"Ukjent\")}')
    print(f'Features: {len(data.get(\"features\", []))}')
    print(f'TODOs: {len(data.get(\"todo_items\", []))}')
    "
fi)

## Neste Steg
$(if [ -f "session_summary.json" ]; then
    python3 -c "
import json
with open('session_summary.json') as f:
    data = json.load(f)
    todos = data.get('todo_items', [])
    if todos:
        for todo in todos[:3]:
            print(f'- {todo}')
    else:
        print('- Fortsett med nåværende arbeid')
    "
fi)

## Viktige Beslutninger
- Bruker FastAPI for backend
- Redis for caching
- Nginx for frontend på port 3001
- GLM-4.5 for AI-funksjonalitet

CONTEXT_EOF

echo "Kontekst lagret i glm-context.txt"
echo "Kopier innholdet fra denne filen til din neste GLM-4.5 økt"
