#!/bin/bash

echo "Tester alle reparasjoner..."

echo "1. Oppdaterer .gitignore"
./update_gitignore.sh

echo ""
echo "2. Oppdaterer session_summary.py"
./fix_session_summary.sh

echo ""
echo "3. Genererer ny session summary"
./scripts/generate_session_summary.sh

echo ""
echo "4. Viser resultat:"
if [ -f "session_summary.json" ]; then
    python3 -c "
import json
with open('session_summary.json') as f:
    data = json.load(f)
    print(f'Features: {len(data.get(\"features\", []))}')
    print(f'TODOs: {len(data.get(\"todo_items\", []))}')
    print(f'API endpoints: {len(data.get(\"api_endpoints\", []))}')
    print()
    print('Features:')
    for feature in data.get('features', [])[:5]:
        print(f'  - {feature}')
    "
else
    echo "session_summary.json ble ikke generert"
fi

echo ""
echo "5. Oppdaterer GLM-4.5 kontekst"
./glm-sync.sh

echo ""
echo "Alle reparasjoner fullført!"
