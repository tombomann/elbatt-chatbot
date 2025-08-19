#!/usr/bin/env bash
# fix-backend-and-deploy.sh
# Retter /api/vegvesen_lookup, /api/varta_lookup, /api/google_feed_match (404),
# oppdaterer Dockerfile/requirements, bygger/pusher & deployer til Scaleway.
# Smoketest inkluderer /health, /api/ping, /api/_diag_env, /api/chat og (valgfritt) eksterne kall.

set -euo pipefail

### ===== Konfig =====
REPO_DIR="/root/elbatt-chatbot"
APP_SUBDIR="backend"
DOCKERFILE="${APP_SUBDIR}/Dockerfile"
REQ_FILE="${APP_SUBDIR}/requirements.txt"
CID="87bbe191-23e8-401e-89fc-ec752616b6e0"   # Scaleway Container ID
NS_NAME="elbatt"
REGION="fr-par"
HOST="chatbot.elbatt.no"
ENV_DATA_FILE="/app/data/products.xlsx"
EXCEL_IN_CONTEXT_REL="${APP_SUBDIR}/data/products.xlsx"

# Smoketest
TEST_PLATE="${TEST_PLATE:-SU18018}"
TEST_QUERY="${TEST_QUERY:-VARTA}"
TEST_CHAT_PAYLOAD='{"message":"Hei"}'
SKIP_EXT_TESTS="${SKIP_EXT_TESTS:-0}"  # 1 = hopp over eksterne tester

### ===== Helpers =====
abort(){ echo "❌ $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || abort "Mangler krav: $1"; }
hr(){ printf '%*s\n' 60 | tr ' ' '='; }

docker_registry_login() {
  # Rydd opp gamle creds for sikkerhets skyld
  docker logout "rg.${REGION}.scw.cloud" >/dev/null 2>&1 || true
  # Prøv flere ganger – nettverk/timeout skjer av og til
  local tries=5
  for i in $(seq 1 $tries); do
    if scw registry login >/dev/null 2>&1; then
      return 0
    fi
    echo "⚠️  registry login feilet (forsøk $i/${tries}), prøver igjen…"
    sleep $((2*i))
  done
  abort "Kunne ikke logge inn på Scaleway registry"
}

### ===== Pre-flight =====
need docker; need scw; need jq; need curl
[ -d "$REPO_DIR" ] || abort "Mappen finnes ikke: $REPO_DIR"
cd "$REPO_DIR"
mkdir -p "${APP_SUBDIR}" "${APP_SUBDIR}/data" "${APP_SUBDIR}/static"

hr; echo "1) Oppdaterer requirements.txt"
cat > "$REQ_FILE" <<'REQ'
fastapi==0.116.1
uvicorn[standard]==0.35.0
pydantic==2.8.2
python-dotenv==1.0.1
openai>=1.30.0
requests==2.32.3
xmltodict==0.13.0
aiofiles==24.1.0
REQ

hr; echo "2) Oppdaterer backend/main.py (endepunkter + chat + diag)"
cat > "${APP_SUBDIR}/main.py" <<'PY'
import os, re, json, xmltodict, requests
from typing import Optional, Dict, Any
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

def _trim(v: Optional[str]) -> str:
    return (v or "").strip()

OPENAI_API_KEY = _trim(os.getenv("OPENAI_API_KEY"))
OPENAI_MODEL   = _trim(os.getenv("OPENAI_MODEL")) or "gpt-4o-mini"
OPENAI_ORG     = _trim(os.getenv("OPENAI_ORG"))
OPENAI_PROJECT = _trim(os.getenv("OPENAI_PROJECT"))
VEGVESEN_API_KEY = _trim(os.getenv("VEGVESEN_API_KEY"))
DATA_FILE = _trim(os.getenv("DATA_FILE")) or "/app/data/products.xlsx"
GOOGLE_FEED_URL = _trim(os.getenv("GOOGLE_FEED_URL")) or "https://elbatt.no/twinxml/google_shopping.php"

app = FastAPI(title="Elbatt API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

class ChatReq(BaseModel):
    message: str

def _mask_key(k: str) -> str:
    return (k[:5] + "…*** len=" + str(len(k))) if k else "(missing)"

def _is_project_key(k: str) -> bool:
    return k.startswith("sk-proj-")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/api/ping")
def ping():
    return {"status": "ok"}

@app.get("/api/_diag_env")
def diag_env():
    key = OPENAI_API_KEY
    return {
        "OPENAI_API_KEY": _mask_key(key),
        "looks_like_sk": key.startswith("sk-"),
        "uses_project_key": _is_project_key(key),
        "OPENAI_ORG_set": bool(OPENAI_ORG),
        "OPENAI_PROJECT_set": bool(OPENAI_PROJECT),
        "OPENAI_MODEL": OPENAI_MODEL,
        "DATA_FILE_exists": os.path.exists(DATA_FILE),
        "SQLITE_exists": os.path.exists("/app/data/products.sqlite"),
    }

# --- Chat ---
try:
    from openai import OpenAI
    _client = OpenAI(api_key=OPENAI_API_KEY, organization=(OPENAI_ORG or None), project=(OPENAI_PROJECT or None)) if OPENAI_API_KEY else None
except Exception:
    _client = None

@app.post("/api/chat")
def chat(req: ChatReq):
    msg = req.message.strip()
    if msg.lower().startswith("plate:"):
        plate = msg.split(":",1)[1].strip()
        try:
            data = vegvesen_lookup(plate)
            return {"type":"vegvesen","data":data}
        except Exception as e:
            return {"type":"vegvesen","error":str(e)}
    if _client:
        try:
            try:
                r = _client.responses.create(model=OPENAI_MODEL, input=msg)
                text = r.output_text
            except Exception:
                r = _client.chat.completions.create(model=OPENAI_MODEL, messages=[{"role":"user","content":msg}])
                text = r.choices[0].message.content
            return {"type":"ai","data":{"answer": text}}
        except Exception as e:
            return {"type":"ai","data":{"answer": f"(Feil mot modell: {e})"}}
    return {"type":"ai","data":{"answer":"Hei! Hvordan kan jeg hjelpe deg i dag?"}}

# --- Vegvesen ---
def vegvesen_lookup(kjennemerke: str) -> Dict[str, Any]:
    if not VEGVESEN_API_KEY:
        raise RuntimeError("VEGVESEN_API_KEY mangler i miljøvariabler")
    url = "https://akfell-datautlevering.atlas.vegvesen.no/enkeltoppslag/kjoretoydata"
    headers = {"X-Env-ApiKey": VEGVESEN_API_KEY, "Accept": "application/json", "User-Agent": "elbatt-chatbot/1.0"}
    r = requests.get(url, params={"kjennemerke": kjennemerke}, headers=headers, timeout=20)
    r.raise_for_status()
    return r.json()

@app.get("/api/vegvesen_lookup")
def vegvesen_lookup_route(kjennemerke: str = Query(..., min_length=2, max_length=10)):
    try:
        return {"ok": True, "data": vegvesen_lookup(kjennemerke)}
    except requests.HTTPError as e:
        return {"ok": False, "error": f"HTTP {e.response.status_code}: {e.response.text}"}
    except Exception as e:
        return {"ok": False, "error": str(e)}

# --- VARTA (scrape "Kortkode") ---
def varta_lookup(plateno: str, platelang: str="nb-NO") -> Dict[str, Any]:
    url = "https://www.varta-automotive.com/nb-no/batterisok"
    r = requests.get(url, params={"plateno": plateno, "platelang": platelang}, timeout=20)
    r.raise_for_status()
    html = r.text
    m = re.search(r"Kortkod[ee]?\s*[:\-]\s*([A-Z0-9\-]{3,})", html, re.IGNORECASE)
    kortkode = m.group(1) if m else None
    return {"plateno": plateno, "kortkode": kortkode, "length": len(html)}

@app.get("/api/varta_lookup")
def varta_lookup_route(plateno: str = Query(..., min_length=2), platelang: str = "nb-NO"):
    try:
        return {"ok": True, "data": varta_lookup(plateno, platelang)}
    except requests.HTTPError as e:
        return {"ok": False, "error": f"HTTP {e.response.status_code}: {e.response.text}"}
    except Exception as e:
        return {"ok": False, "error": str(e)}

# --- Google feed (XML) ---
def google_feed_match(q: str, limit: int = 5) -> Dict[str, Any]:
    url = GOOGLE_FEED_URL or "https://elbatt.no/twinxml/google_shopping.php"
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    data = xmltodict.parse(r.text)
    items = []
    try:
        channel = data.get("rss", {}).get("channel", {})
        items = channel.get("item", []) or []
    except Exception:
        pass
    if isinstance(items, dict):
        items = [items]
    ql = q.lower()
    def pick(d,k,default=""):
        v = d.get(k) if isinstance(d, dict) else None
        return v if isinstance(v, str) else default
    out=[]
    for it in items:
        title = pick(it,"title"); desc=pick(it,"description"); link=pick(it,"link")
        if (ql in title.lower()) or (ql in desc.lower()):
            out.append({"title": title, "link": link})
        if len(out) >= limit: break
    return {"query": q, "count": len(out), "items": out}

@app.get("/api/google_feed_match")
def google_feed_match_route(q: str = Query(..., min_length=2), limit: int = 5):
    try:
        return {"ok": True, "data": google_feed_match(q, limit)}
    except requests.HTTPError as e:
        return {"ok": False, "error": f"HTTP {e.response.status_code}: {e.response.text}"}
    except Exception as e:
        return {"ok": False, "error": str(e)}
PY

hr; echo "3) Dockerfile (COPY backend + ENV DATA_FILE)"
cat > "$DOCKERFILE" <<'DOCK'
FROM python:3.12-slim AS base
WORKDIR /app
COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

FROM python:3.12-slim
WORKDIR /app
COPY --from=base /usr/local/lib/python3.12 /usr/local/lib/python3.12
COPY --from=base /usr/local/bin /usr/local/bin
COPY backend /app
ENV DATA_FILE=/app/data/products.xlsx
ENV GOOGLE_FEED_URL=https://elbatt.no/twinxml/google_shopping.php
EXPOSE 8000
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]
DOCK

# Placeholder for Excel hvis mangler
if [ ! -s "$EXCEL_IN_CONTEXT_REL" ]; then
  echo "⚠️  Ingen Excel funnet – lager tom placeholder: ${EXCEL_IN_CONTEXT_REL}"
  : > "$EXCEL_IN_CONTEXT_REL"
fi

hr; echo "4) Finn registry endpoint og bygg/push"
REGISTRY_FQDN="$(scw registry namespace list -o json | jq -r ".[] | select(.name==\"$NS_NAME\" and .region==\"$REGION\") | .endpoint")"
[ -n "$REGISTRY_FQDN" ] || abort "Fant ikke registry-endpoint for namespace=$NS_NAME region=$REGION"

TAG="prod-$(date +%Y%m%d%H%M%S)"
IMAGE="${REGISTRY_FQDN}/${NS_NAME}/elbatt-chatbot:${TAG}"
echo "→ Bygger: $IMAGE"
DOCKER_CLIENT_TIMEOUT=300 COMPOSE_HTTP_TIMEOUT=300 docker build -t "$IMAGE" "$REPO_DIR"

echo "→ Logger inn i registry (med retry)…"
docker_registry_login

echo "→ Push image"
DOCKER_CLIENT_TIMEOUT=300 COMPOSE_HTTP_TIMEOUT=300 docker push "$IMAGE"

hr; echo "5) Oppdater container og deploy"
scw container container update "$CID" registry-image="$IMAGE" \
  health-check.http.path="/health" \
  health-check.failure-threshold=5 \
  health-check.interval=10s \
  port=8000 http-option=enabled timeout=300s >/dev/null
scw container container deploy "$CID" >/dev/null
echo "✓ Deploy sendt"

hr; echo "6) Smoketest"
set +e
echo "-- /health"
curl -fsS "https://${HOST}/health" || echo "FEIL: /health"; echo
echo "-- /api/ping"
curl -fsS "https://${HOST}/api/ping" || echo "FEIL: /api/ping"; echo
echo "-- /api/_diag_env"
curl -fsS "https://${HOST}/api/_diag_env" || echo "FEIL: /api/_diag_env"; echo
echo "-- /api/chat"
curl -fsS -H "Content-Type: application/json" -d "${TEST_CHAT_PAYLOAD}" "https://${HOST}/api/chat" || echo "FEIL: /api/chat"; echo

if [ "$SKIP_EXT_TESTS" != "1" ]; then
  echo "-- /api/vegvesen_lookup?kjennemerke=${TEST_PLATE}"
  curl -fsS "https://${HOST}/api/vegvesen_lookup?kjennemerke=${TEST_PLATE}" || echo "FEIL: /api/vegvesen_lookup"; echo
  echo "-- /api/varta_lookup?plateno=${TEST_PLATE}"
  curl -fsS "https://${HOST}/api/varta_lookup?plateno=${TEST_PLATE}" || echo "FEIL: /api/varta_lookup"; echo
  echo "-- /api/google_feed_match?q=${TEST_QUERY}"
  curl -fsS "https://${HOST}/api/google_feed_match?q=${TEST_QUERY}" || echo "FEIL: /api/google_feed_match"; echo
else
  echo "⏭ Hopper over eksterne tester (SKIP_EXT_TESTS=1)"
fi

hr
echo "Ferdig!  Image: ${IMAGE}"
echo "Tips:"
echo " - Sørg for at Secrets er satt i containeren: OPENAI_API_KEY og VEGVESEN_API_KEY."
echo " - DATA_FILE forventes i ${ENV_DATA_FILE} (placeholder er ok inntil Excel er klar)."
