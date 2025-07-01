#!/bin/bash
set -e

echo "🔧 Setter opp AI-basert feilretting for Elbatt Chatbot..."

# 1. Opprett nødvendige mapper
mkdir -p .github/workflows
mkdir -p .github/ai-fixes

# 2. Last ned ferdig workflow (rediger filnavn/URL om du vil ha egen kopi)
curl -fsSL https://raw.githubusercontent.com/tombomann/elbatt-chatbot/main/.github/workflows/ci-auto-ai-fix.yml -o .github/workflows/ci-auto-ai-fix.yml

# 3. (Valgfritt) Last ned AI-reparasjons-script hvis du ønsker custom scripts i .github/ai-fixes

# 4. Legg til, committer og pusher til main
git add .github/workflows/ci-auto-ai-fix.yml
git commit -m "Legg til AI-drevet automatisk feilretting i pipeline"
git push origin main

echo "✅ Alt klart! Neste feil i CI/CD vil bli analysert og foreslått rettet med AI."
