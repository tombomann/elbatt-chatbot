# elbatt-chatbot

Backend for Elbatt Chatbot. Kjøres på **Scaleway Containers** og eksponeres via egendomenet **chatbot.elbatt.no** med automatisk Let's Encrypt-sertifikat. Dette repoet inneholder runbook for drift, deploy og DNS/sertifikat.

> TL;DR
>
> 1. Oppdater env & secrets → 2) Deploy container → 3) Bind domene → 4) Vent til `ready` → 5) Verifiser med `/health`.

---

## Innhold

* [Arkitektur](#arkitektur)
* [Forutsetninger](#forutsetninger)
* [Scaleway CLI: nøkler & profiler](#scaleway-cli-nøkler--profiler)
* [Konfigurasjon (env/secrets)](#konfigurasjon-envsecrets)
* [Deploy til Scaleway](#deploy-til-scaleway)
* [Domene & DNS](#domene--dns)
* [Verifisering](#verifisering)
* [Batch-jobber (Scaleway Jobs)](#batch-jobber-scaleway-jobs)
* [Feilsøking](#feilsøking)
* [Hjelpefunksjoner](#hjelpefunksjoner)
* [API](#api)
* [Sikkerhet & nøkler](#sikkerhet--nøkler)
* [Lisens](#lisens)

---

## Arkitektur

* **Container:** `elbatt-api` (Scaleway Containers)
* **Image:** `rg.fr-par.scw.cloud/elbatt/chatbot-backend:latest`
* **Port/Proto:** HTTP/1 på `:8000` (Container), publisert via Scaleway sin managed inngang.
* **Domene:** `chatbot.elbatt.no` (CNAME → Scaleway-funksjonsdomene)
* **Sertifikat:** Let's Encrypt (automatisk utstedt av Scaleway Domain-binding)
* **Helse-endepunkt:** `GET /health` → `{ "status": "healthy" }`

> Merk: `A`/`AAAA` for `chatbot.elbatt.no` vil vise IP-ene til *måldomenet*, ikke en lokal A-record. Vi bruker **CNAME**.

---

## Forutsetninger

Installer lokalt:

* **Scaleway CLI** ≥ 2.41 (`scw`)
* **jq**, **curl**, **openssl**
* Tilgang til Scaleway-prosjektet + Domeneshop (for DNS)

Konfigurer Scaleway-auth (en gang):

```bash
scw init
scw config get default-region   # bør være fr-par
```

---

## Scaleway CLI: nøkler & profiler

> Kortversjon: lag API key i riktig org → lag/oppdater profilen `elbatt` → aktiver → test.

### 0) Null ut miljøvariabler som kan overstyre

```bash
unset SCW_ACCESS_KEY SCW_SECRET_KEY SCW_DEFAULT_ORGANIZATION_ID SCW_DEFAULT_PROJECT_ID SCW_DEFAULT_REGION SCW_DEFAULT_ZONE
```

### 1) Lag API key i riktig organisasjon

* Console → **IAM → API keys → Create** (org: `50108dee-3a8f-4f4d-a007-6cc51d5c06de`).
* Du får en **Access Key** (starter med `SCW...`, 20 tegn) og en **Secret Key** (full UUID).

### 2) Konfigurer/aktiver profilen `elbatt`

```bash
scw config set access-key="SCWXXXXXXXXXXXXXXXXX"                 --profile elbatt
scw config set secret-key="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" --profile elbatt
scw config set default-organization-id=50108dee-3a8f-4f4d-a007-6cc51d5c06de --profile elbatt
scw config set default-project-id=50108dee-3a8f-4f4d-a007-6cc51d5c06de      --profile elbatt
scw config set default-region=fr-par                                    --profile elbatt
scw config set default-zone=fr-par-1                                    --profile elbatt
scw config profile activate elbatt
```

### 3) Verifiser profilen

```bash
scw -p elbatt config get access-key
scw -p elbatt config get default-region
scw -p elbatt config get default-zone
scw -p elbatt container namespace list region=fr-par -o json | jq -r '.[].name'
```

Forvent at siste kommando viser f.eks. `elbatt-langflow`.

### Tips

* `SCW_*` miljøvariabler **overstyrer** config. Hold dem tomme (bruk `unset …`) eller legg alltid til `-p elbatt`.
* Ikke lim inn nøkler i repo eller terminalhistorikk. Skriv secret uten ekko:

```bash
read -s SK && scw config set secret-key="$SK" --profile elbatt
```

### Rotasjon (valgfritt)

Søk opp og slett en API key når den ikke trengs lenger:

```bash
KEY_ID="$(scw -p elbatt iam api-key list -o json \
  | jq -r '.[] | select(.access_key=="SCWXXXXXXXXXXXXXXXXX") | .id')"
[ -n "$KEY_ID" ] && scw -p elbatt iam api-key delete "$KEY_ID"
```

## Konfigurasjon (env/secrets)

Miljøvariabler i containeren:

| Variabel            | Type   | Beskrivelse                         |
| ------------------- | ------ | ----------------------------------- |
| `OPENAI_MODEL`      | env    | OpenAI modell, f.eks. `gpt-4o-mini` |
| `VEGVESEN_ENDPOINT` | env    | `https://api.vegvesen.no/vehicles`  |
| `OPENAI_API_KEY`    | secret | OpenAI API-nøkkel                   |
| `VEGVESEN_API_KEY`  | secret | API-nøkkel til Statens vegvesen     |

Sett opp (erstatt variabler for din konto):

```bash
export REGION="fr-par"
export CONTAINER_ID="<container-uuid>"

# Env
scw container container update "$CONTAINER_ID" \
  environment-variables.OPENAI_MODEL=gpt-4o-mini \
  environment-variables.VEGVESEN_ENDPOINT=https://api.vegvesen.no/vehicles \
  region="$REGION"

# Secrets (indekseres 0,1,2...)
scw container container update "$CONTAINER_ID" \
  secret-environment-variables.0.key=OPENAI_API_KEY \
  secret-environment-variables.0.value="$OPENAI_API_KEY_VAL" \
  secret-environment-variables.1.key=VEGVESEN_API_KEY \
  secret-environment-variables.1.value="$VEGVESEN_API_KEY_VAL" \
  region="$REGION"
```

---

## Deploy til Scaleway

```bash
# Rull ut siste image/konfig
scw container container deploy "$CONTAINER_ID" region="$REGION"
```

Sjekk at containeren er oppdatert:

```bash
scw container container get "$CONTAINER_ID" -o json | \
  jq '{env: .environment_variables, secret_keys: [.secret_environment_variables[].key], domain: .domain_name}'
```

---

## Domene & DNS

### 1) Bind domene til container

```bash
HOSTNAME="chatbot.elbatt.no"
# Finn ev. eksisterende domain-id og slett
DID="$(scw container domain list region="$REGION" -o json | jq -r --arg h "$HOSTNAME" '.[] | select(.hostname==$h) | .id' | head -n1)"
[ -n "$DID" ] && scw container domain delete "$DID" region="$REGION" || true

# Opprett binding
scw container domain create container-id="$CONTAINER_ID" hostname="$HOSTNAME" region="$REGION"
```

### 2) DNS hos Domeneshop

* **chatbot.elbatt.no** → **CNAME** → verdien fra Scaleway (ser ut som `...functions.fnc.fr-par.scw.cloud.`)
* På **elbatt.no (apex)**: **CAA 0 issue "letsencrypt.org"** (allerede lagt inn)
* **Ikke** legg CAA på `chatbot.elbatt.no` når det er CNAME – CAA **arves** fra apex.

> Domeneshop UI vil vise varsel hvis du forsøker å legge CAA på `chatbot.*` – det er etter boka.

---

## Verifisering

Når DNS er på plass og Scaleway har utstedt sertifikat, skal domenestatus bli `ready`.

```bash
# Vent til klar
scw container domain list region="$REGION" -o json | jq -r '.[] | select(.hostname=="chatbot.elbatt.no") | .status'

# Sertifikatets SAN må være chatbot.elbatt.no
HOST=chatbot.elbatt.no
openssl s_client -servername "$HOST" -connect "$HOST:443" </dev/null 2>/dev/null \
  | openssl x509 -noout -dates -ext subjectAltName

# Health
curl -fsS https://chatbot.elbatt.no/health
# {"status":"healthy"}
```

*Tips:* `dig +short CNAME chatbot.elbatt.no` bør vise funksjonsdomenet. `dig +short A/AAAA` vil typisk vise IP-er til mål-domenet (forventet).

---

## Batch-jobber (Scaleway Jobs)

Kjøre en job-run med miljøvariabel (eksempel: slå opp skilt/plate):

```bash
export JOB_DEF_ID="<job-definition-uuid>"

# Start og hent run-id fra output
RUN_ID="$(scw jobs definition start "$JOB_DEF_ID" environment-variables.PLATE=SU18018 region="$REGION" -o json \
  | jq -r '.job_runs[0].id // .job_run_id // .jobRun.id // .job_run.id')"

# Vent på ferdig
scw jobs run wait "$RUN_ID" region="$REGION"
```

Eksempel på suksess:

```
State: succeeded, ExitCode: 0, EnvironmentVariables.PLATE=SU18018
```

---

## Feilsøking

### «SSL: no alternative certificate subject name matches target host name»

Årsak: Sertifikatet er ikke klart / feil binding. Løsning:

1. Sjekk domenestatus i Scaleway:

   ```bash
   scw container domain list region="$REGION" -o json | jq -r '.[] | select(.hostname=="chatbot.elbatt.no") | .status'
   scw container domain get <DOMAIN_ID> region="$REGION" -o json | jq .
   ```
2. Verifiser DNS i Domeneshop: `chatbot.elbatt.no` **CNAME** → funksjonsdomenet.
3. Bekreft CAA på **elbatt.no** er `issue "letsencrypt.org"` (ingen CAA på `chatbot.*`).
4. Vent til status **ready** (se skript under).

### «Invalid region»

* Bruk `region=fr-par` (ingen `--region`).
* Sjekk standard: `scw config get default-region` → `fr-par`.

### Domenestatus henger på `pending`

* CNAME ikke publisert enda (TTL).
* Evt. gammel binding eksisterer → slett og opprett på nytt.
* Bruk *wait*-funksjonen under for å vente til `ready`.

---

## Hjelpefunksjoner

Legg i `scripts/scw-helpers.sh` og `source` ved behov.

```bash
scw_job_run() {
  local def_id="$1"; shift
  local region="${REGION:-fr-par}"
  scw jobs definition start "$def_id" "$@" region="$region" -o json \
    | jq -r '.job_runs[0].id // .job_run_id // .jobRun.id // .job_run.id'
}

scw_domain_delete_by_host() {
  local host="$1" region="${2:-fr-par}"
  scw container domain list region="$region" -o json \
    | jq -r --arg h "$host" '.[] | select(.hostname==$h) | .id' \
    | xargs -r -n1 -I{} scw container domain delete {} region="$region"
}

scw_domain_status() {
  local host="$1" region="${2:-fr-par}"
  scw container domain list region="$region" -o json \
    | jq -r --arg h "$host" '.[] | select(.hostname==$h) | "\(.hostname)\t\(.status)\t\(.url)"'
}

wait_domain_ready() {
  local host="$1" region="${2:-fr-par}";
  while true; do
    st="$(scw container domain list region="$region" -o json \
        | jq -r --arg h "$host" '.[]|select(.hostname==$h)|.status')"
    case "$st" in
      ready) break ;;
      error)
        scw container domain get "$(scw container domain list region="$region" -o json \
          | jq -r --arg h "$host" '.[]|select(.hostname==$h)|.id' | head -n1)" \
          region="$region" -o json | jq -r '.error_message'
        return 1 ;;
    esac
    sleep 5
  done
}
```

---

## API

* `GET /health` → `200 OK` og `{ "status": "healthy" }`

Eksempel:

```bash
curl -fsS https://chatbot.elbatt.no/health | jq .
```

---

## Sikkerhet & nøkler

* **Ikke** commite nøkler i repoet. Bruk Scaleway Secrets som vist over.
* Tilganger til Domeneshop og Scaleway bør være MFA-beskyttet.

---

## Lisens

MIT (endre hvis ønskelig).

---

##
