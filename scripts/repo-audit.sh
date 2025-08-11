#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
OUT="$ROOT/REPORT.md"

say(){ echo "[$(date +'%F %T')] $*"; }

has(){ test -e "$ROOT/$1" && echo "✅ $1" || echo "❌ $1"; }

detect_backend(){
  if grep -RIlq "from fastapi" "$ROOT"; then echo "Backend: FastAPI (✅)";
  elif grep -RIlq "from flask" "$ROOT"; then echo "Backend: Flask (⚠️ vurder migrasjon)";
  else echo "Backend: Ukjent (🔎)"; fi
}

detect_embed(){
  if grep -RIlq "embed.js" "$ROOT"; then echo "Frontend: embed.js (✅)"; else echo "Frontend: embed.js ikke funnet (⚠️)"; fi
}

detect_react(){
  if [ -f "$ROOT/frontend/package.json" ] || grep -RIlq "react" "$ROOT"; then
    echo "React-prosjekt oppdaget (🔎)"; else echo "React-prosjekt ikke oppdaget (OK)"; fi
}

detect_langflow(){
  if grep -RIlq "langflow" "$ROOT"; then echo "Langflow: referanser funnet (✅)"; else echo "Langflow: ikke funnet (⚠️)"; fi
}

detect_glm(){
  if grep -RIlq "GLM-4.5" "$ROOT"; then echo "GLM-4.5: omtalt (🔎 verifiser faktisk bruk)"; else echo "GLM-4.5: ikke i bruk (OK)"; fi
}

detect_redis(){
  if grep -RIlq "redis" "$ROOT/docker-compose"* "$ROOT/k8s" 2>/dev/null; then
    echo "Redis: konfigurert (🔎)"; else echo "Redis: ikke konfigurert (⚠️ planlagt)"; fi
}

detect_k8s(){
  if [ -d "$ROOT/k8s" ] || ls "$ROOT" | grep -qiE 'k8s|kubernetes|manifests'; then
    echo "Kubernetes: manifester finnes (🔎)"; else echo "Kubernetes: manifester mangler (⚠️)"; fi
}

detect_sonar(){
  if [ -f "$ROOT/.sonarcloud.properties" ] || grep -RIlq "sonarcloud" "$ROOT/.github/workflows" 2>/dev/null; then
    echo "SonarCloud: konfigurert (🔎)"; else echo "SonarCloud: mangler (⚠️)"; fi
}

detect_playwright(){
  if grep -RIlq "playwright" "$ROOT"; then echo "Playwright: funnet (✅)"; else echo "Playwright: ikke funnet (⚠️)"; fi
}

say "Analyserer repo i: $ROOT"
{
  echo "# Elbatt Chatbot – Repo Audit"
  echo
  echo "## Struktur-sjekk"
  has "backend"; has "public/embed.js"; has ".github/workflows"; has "k8s"
  echo
  echo "## Teknologi-deteksjon"
  detect_backend
  detect_embed
  detect_react
  detect_langflow
  detect_glm
  detect_redis
  detect_k8s
  detect_sonar
  detect_playwright
  echo
  echo "## Anbefalt neste steg (automatisk generert)"
  echo "- Oppdater README/sammenligningstabellen i tråd med funnene over."
  echo "- Hvis GLM-4.5 skal inn: legg til klient, konfig, feature-flag og e2e-test."
  echo "- Legg inn Redis (compose/k8s) for regnr→Varta→produkt cache."
  echo "- Bekreft k8s-namespace og manifester; legg health/liveness/readiness."
  echo "- Sikre Sonar-gate + coverage i CI."
  echo "- Herd Playwright med popup-killer + retry/backoff."
} > "$OUT"

say "Rapport skrevet til $OUT"
