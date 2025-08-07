#!/bin/bash

echo "Fikser funksjonsdeteksjon i session_summary.py..."

# Først, la oss se hva som faktisk er i GLM-4.5-FEATURES.md
echo "Innhold i GLM-4.5-FEATURES.md:"
echo "================================"
head -20 GLM-4.5-FEATURES.md
echo "================================"
echo ""

# Oppdater session_summary.py med en forbedret get_current_features funksjon
cat > backend/session_summary.py << 'PYEOF'
import os
import json
import re
from datetime import datetime

def get_current_features():
    """Henter liste over implementerte funksjoner"""
    try:
        with open("GLM-4.5-FEATURES.md", "r") as f:
            content = f.read()
            features = []
            
            # Finn seksjonen "Implementerte Funksjoner"
            in_features_section = False
            for line in content.split('\n'):
                # Sjekk om vi er i "Implementerte Funksjoner" seksjonen
                if "Implementerte Funksjoner" in line:
                    in_features_section = True
                    continue
                
                # Hvis vi kommer til en ny seksjon, stopp
                if in_features_section and line.strip().startswith('-') and "Funksjoner" in line:
                    break
                
                # Samle funksjoner i denne seksjonen
                if in_features_section and ('- [x]' in line or '✓' in line):
                    # Fjern markdown og whitespace
                    feature = re.sub(r'^[\s\-\*\✓\[\]x]+', '', line).strip()
                    if feature:
                        features.append(feature)
            
            return features if features else ["Ingen funksjoner funnet i GLM-4.5-FEATURES.md"]
    except FileNotFoundError:
        return ["Kunne ikke finne GLM-4.5-FEATURES.md"]

def get_recent_changes():
    """Henter nylige endringer fra git"""
    try:
        result = os.popen("git log --oneline -10").read().strip()
        return result.split('\n') if result else []
    except:
        return ["Kunne ikke hente git-logg"]

def get_todo_items():
    """Henter TODO-elementer fra prosjektet"""
    todos = []
    try:
        # Søk etter TODO i Python-filer
        for root, dirs, files in os.walk("."):
            for file in files:
                if file.endswith(".py"):
                    with open(os.path.join(root, file), "r") as f:
                        for i, line in enumerate(f):
                            if "TODO" in line or "FIXME" in line:
                                todos.append(f"{file}:{i+1} - {line.strip()}")
    except:
        pass
    return todos if todos else ["Ingen TODO-elementer funnet"]

def get_api_endpoints():
    """Henter API-endepunkter fra main.py"""
    try:
        with open("backend/main.py", "r") as f:
            content = f.read()
            endpoints = []
            for line in content.split('\n'):
                if '@app.' in line and ('get' in line or 'post' in line):
                    endpoints.append(line.strip())
            return endpoints
    except FileNotFoundError:
        return ["Kunne ikke finne backend/main.py"]

def create_session_summary():
    """Lager et sammendrag av nåværende prosjektstatus"""
    summary = {
        "timestamp": datetime.now().isoformat(),
        "last_commit": os.popen("git log -1 --pretty=format:'%h - %s (%cr)'").read().strip(),
        "features": get_current_features(),
        "recent_changes": get_recent_changes(),
        "todo_items": get_todo_items(),
        "api_endpoints": get_api_endpoints()
    }
    
    with open("session_summary.json", "w") as f:
        json.dump(summary, f, indent=2)
    
    return summary

if __name__ == "__main__":
    summary = create_session_summary()
    print("Session summary created successfully!")
    print(f"Features: {len(summary['features'])}")
    print(f"Recent changes: {len(summary['recent_changes'])}")
    print(f"TODO items: {len(summary['todo_items'])}")
    print(f"API endpoints: {len(summary['api_endpoints'])}")
PYEOF

echo "session_summary.py oppdatert med forbedret funksjonsdeteksjon"

echo "Tester ny funksjon..."
python3 -c "
import sys
sys.path.append('backend')
from session_summary import get_current_features
features = get_current_features()
print(f'Fant {len(features)} funksjoner:')
for i, feature in enumerate(features, 1):
    print(f'{i}. {feature}')
"
