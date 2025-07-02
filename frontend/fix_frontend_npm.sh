#!/bin/bash
set -e

# --- 1. Gå til frontend og reset npm --
echo "🧹 Rydder opp frontend avhengigheter..."
cd frontend
rm -rf node_modules package-lock.json
npm install

echo "✅ Installerte avhengigheter på nytt"

# --- 2. Legg til workflow for AI-autofix (kun hvis den ikke finnes) ---
cd ..
WORKFLOW_FILE=".github/workflows/ci-ai-autofix.yml"
if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "🛠️ Legger til AI-autofix-workflow..."
  mkdir -p .github/workflows
  cat > $WORKFLOW_FILE <<EOF
name: AI Autofix npm/react-scripts

on: [push, pull_request]

jobs:
  ai-autofix:
    runs-on: ubuntu-latest
    if: \${{ github.actor != 'github-actions[bot]' }}

    steps:
      - name: Sjekk ut repo
        uses: actions/checkout@v4

      - name: Kjør npm install og patch react-scripts hvis feil
        run: |
          cd frontend
          if ! grep -q '"react-scripts":' package.json; then
            npm install react-scripts@5.0.1 --save
          fi
          npm install || ( \\
            rm -rf node_modules package-lock.json && \\
            npm install \\
          )
          cd ..

      - name: Commit fix hvis noe ble endret
        run: |
          if [[ -n "\$(git status --porcelain)" ]]; then
            git config user.name "Elbatt Bot"
            git config user.email "bot@elbatt.no"
            git add frontend/package.json frontend/package-lock.json
            git commit -m "AI-autofix: react-scripts og npm-lock auto-patch"
            git push origin HEAD:ai-autofix-\${{ github.run_id }}
          fi
        continue-on-error: true

      - name: Opprett PR hvis endringer
        uses: peter-evans/create-pull-request@v6
        with:
          branch: ai-autofix-\${{ github.run_id }}
          delete-branch: true
          title: "AI-autofix: react-scripts og npm-lock"
          body: |
            Automatisk rettet react-scripts/npm-lock problem.
            Kan merges direkte hvis tests er grønne.
        if: \${{ success() }}
EOF
fi

echo "📝 Lagt inn workflow for fremtidig AI-autofix"

# --- 3. Commit og push alt (krever at du har rettigheter og er logget inn) ---
git add frontend/package.json frontend/package-lock.json $WORKFLOW_FILE
git commit -m "Fiks: npm/react-scripts + AI-autofix-workflow"
git pull --rebase origin main
git push origin main

echo "🚀 Ferdig! Sjekk Github Actions – alt går automatisk neste gang!"
