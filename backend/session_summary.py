import os
import json
from datetime import datetime

def get_current_features():
    """Henter liste over implementerte funksjoner"""
    try:
        with open("GLM-4.5-FEATURES.md", "r") as f:
            content = f.read()
            # Trekk ut alle linjer med ✓
            features = []
            for line in content.split('\n'):
                if '✓' in line:
                    features.append(line.strip())
            return features
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
