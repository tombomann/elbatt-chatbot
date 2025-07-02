#!/bin/bash
set -e

echo "🔧 Rydder opp package-lock.json-konflikt i frontend..."

# 1. Slett package-lock.json og node_modules
rm -f frontend/package-lock.json
rm -rf frontend/node_modules

# 2. Installer alt på nytt i frontend
cd frontend
npm install
cd ..

# 3. Legg til og marker konflikten som løst
git add frontend/package-lock.json

# 4. Fullfør evt. pågående rebase
if git status | grep -q 'rebase in progress'; then
    echo "🚦 Rebase pågår, prøver å fortsette..."
    git rebase --continue || true
fi

# 5. Push til GitHub
git push origin main

echo "✅ Ferdig! package-lock.json er frisk, og alle endringer pushet til main."
