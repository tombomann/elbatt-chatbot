# elbatt-chatbot

Embedbar chatbot + API for elbatt.no.  
Støtter kjennemerkeoppslag (plate → produktmatch), enkel scraping og forslag til batteri/lader.

![Status](https://img.shields.io/badge/deploy-Scaleway%20Serverless-informational)
![Node](https://img.shields.io/badge/node-%3E=20.x-blue)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## Innhold

- [Arkitektur](#arkitektur)
- [API](#api)
- [Miljøvariabler](#miljøvariabler)
- [Lokal utvikling](#lokal-utvikling)
- [Drift – Anbefalt: Scaleway Serverless Containers](#drift--anbefalt-scaleway-serverless-containers)
- [Fallback – Ubuntu VM (systemd + Nginx + Certbot)](#fallback--ubuntu-vm-systemd--nginx--certbot)
- [Sikkerhet](#sikkerhet)
- [CI/CD](#cicd)
- [Feilsøking](#feilsøking)
- [Lisens](#lisens)

---

## Arkitektur

**Klient** → `embed.js` → **API** (Express) → **(Playwright) scraping** → **Produktdata (feed/CSV)**

Driftsvarianter:
- **Serverless (anbefalt)**: API som container i *Scaleway Serverless Containers*, secrets i *Scaleway Secrets Manager*, image i Scaleway Registry.  
- **VM (fallback)**: `systemd` kjører Node (`:8001`), Nginx proxy (`80/443`) med Let’s Encrypt.

_Mer info om Serverless Containers og Functions + Secrets:_  
Scaleway docs: Serverless Containers / Functions / Secrets / Secret Manager.  
(Bruk Secrets for API‑nøkler; ikke sjekk inn sensitive verdier.)

> Referanser:  
> – Serverless Containers (hurtigstart/konsepter): scaleway.com/en/docs/serverless-containers/  
> – Secrets i Functions/Secrets Manager: se docs om *Secrets* og *Secret Manager*  
> – Teknisk bakgrunn: Serverless Containers (Knative‑basert)  
> – Disse referansene brukes i prosjektets drift/CI (se nedenfor).

---

## API

Base: `https://chatbot.elbatt.no/api` (prod) / `http://127.0.0.1:8001/api` (lokalt)

- `GET /health`  
  **200** → `{ ok: true, service: "elbatt-plate", version, uptime_s, timestamp }`

- `GET /battery-by-plate?regnr=SU18018`  
  Returnerer `{ ok, regnr, vehicle?, varta?, matches[] }`  
  NB: Sett `PLATE_API_URL`/`PLATE_API_TOKEN` hvis du vil auto‑rette merke/modell/år.

---

## Miljøvariabler

| Navn | Beskrivelse | Eksempel/verdi |
|---|---|---|
| `PORT` | API-port (lokalt/VM) | `8001` |
| `ALLOWED_ORIGIN` | CORS tillatt opprinnelse | `https://www.elbatt.no` |
| `FEED_URL` | Produktfeed/CSV/Google shopping | `https://elbatt.no/twinxml/google_shopping.php` |
| `VARTA_BASE` | VARTA batteri‑finner (landside) | `https://www.varta-automotive.com/nb-no/battery-finder` |
| `PLATE_API_URL` | Eksternt kjennemerke‑API | `https://din-leverandor/api?regnr={REGNR}` |
| `PLATE_API_TOKEN` | Token til kjennemerke‑API | `${secret}` |
| `CACHE_DIR` | Cache på disk (VM) | `/var/cache/elbatt-plate` |

> På **Scaleway Serverless** skal secrets legges i Secret Manager og injiseres som miljø­variabler (ikke i repo).

---

## Lokal utvikling

```bash
# krav
Node 20+, npm
# (Playwright installeres automatisk av skript ved første kjøring)

# 1) Installer
npm ci

# 2) Kjør API
npm run dev   # eller: node server.mjs

# 3) Test
curl -s http://127.0.0.1:8001/api/health | jq .
