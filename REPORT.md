# Elbatt Chatbot – Repo Audit

## Struktur-sjekk
✅ backend
✅ public/embed.js
✅ .github/workflows
✅ k8s

## Teknologi-deteksjon
Backend: FastAPI (✅)
Frontend: embed.js (✅)
React-prosjekt oppdaget (🔎)
Langflow: referanser funnet (✅)
GLM-4.5: omtalt (🔎 verifiser faktisk bruk)
Redis: konfigurert (🔎)
Kubernetes: manifester finnes (🔎)
SonarCloud: konfigurert (🔎)
Playwright: funnet (✅)

## Anbefalt neste steg (automatisk generert)
- Oppdater README/sammenligningstabellen i tråd med funnene over.
- Hvis GLM-4.5 skal inn: legg til klient, konfig, feature-flag og e2e-test.
- Legg inn Redis (compose/k8s) for regnr→Varta→produkt cache.
- Bekreft k8s-namespace og manifester; legg health/liveness/readiness.
- Sikre Sonar-gate + coverage i CI.
- Herd Playwright med popup-killer + retry/backoff.
