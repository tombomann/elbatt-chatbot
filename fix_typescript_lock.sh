#!/bin/bash
set -e

cd "$(dirname "$0")/frontend"

echo "🧹 Fjerner gamle node_modules og lockfile..."
rm -rf node_modules package-lock.json

# === SJEKKER OM DU EGENTLIG BRUKER TYPESCRIPT ===
if grep -q '"typescript"' package.json; then
    echo "🛠 Låser typescript til 4.9.5 i package.json..."
    # Bytt til 4.9.5 uansett om det ligger under dependencies eller devDependencies
    sed -i 's/"typescript": *"[^"]*"/"typescript": "4.9.5"/g' package.json
else
    echo "❗ Ingen typescript funnet i package.json (bra hvis du ikke bruker det)."
fi

echo "📦 Installerer alle avhengigheter på nytt..."
npm install

echo "✅ Tester at npm ci nå er grønn..."
npm ci

echo "🔨 Bygger frontend for å verifisere..."
npm run build

cd ..
echo "📝 Gjør klar for commit..."
git add frontend/package.json frontend/package-lock.json
git commit -m "Full auto-fiks: Lås typescript til 4.9.5 og rebuild, npm ci OK"
git pull --rebase origin main || true
git push origin main

echo "🚀 Ferdig! npm ci burde nå alltid være grønn i CI/CD!"
