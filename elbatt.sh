#!/usr/bin/env bash
# elbatt.sh — masterorchestrator for embed.js + backend patch + build + tester
# Bruk:
#   ./elbatt.sh all          # installer skript, patch, build, tester
#   ./elbatt.sh install      # bare legg alle skript i ./scripts/
#   ./elbatt.sh build        # build & start via docker compose
#   ./elbatt.sh diagnose     # korte lokale og eksterne tester
#   ./elbatt.sh inline       # generer inline-embed.html (fallback)

set -Eeuo pipefail

HERE="$(pwd)"
SCRIPTS_DIR="${HERE}/scripts"
SERVICE="${SERVICE:-api}"
PORT_TEST="${PORT_TEST:-8000}"

say(){ printf "\n==> %s\n" "$*"; }
note(){ printf "   -> %s\n" "$*"; }

# --- Compose deteksjon ---
detect_compose(){
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
    return
  fi
  echo ""
}

COMPOSE="$(detect_compose)"

# --- Installer alle hjelpeskript til ./scripts/ ---
install_scripts() {
  mkdir -p "${SCRIPTS_DIR}"

  # 1) fix-embed.sh (sikrer backend/static/embed.js)
  cat > "${SCRIPTS_DIR}/fix-embed.sh" <<'BASH'
#!/usr/bin/env bash
set -Eeuo pipefail
EMBED="backend/static/embed.js"
echo "==> Sikrer at ${EMBED} finnes"
if [ ! -f "${EMBED}" ]; then
  mkdir -p "$(dirname "${EMBED}")"
  cat > "${EMBED}" <<'JS'
/*! elbatt embed (minimal bootstrap) */
(function(){
  if (window.__ElbattEmbedLoaded) return; window.__ElbattEmbedLoaded = true;
  var s=document.currentScript||{};
  var BASE=(window.ELBATT_CHAT_API || (s.dataset && s.dataset.api) || 'https://chatbot.elbatt.no').replace(/\/+$/,'');
  var st=document.createElement('style');
  st.textContent=".elbat-wrap{position:fixed;right:16px;bottom:16px;z-index:2147483000;font-family:system-ui,Roboto,Arial,sans-serif}.elbat-btn{border:0;border-radius:999px;padding:10px 14px;background:#0ea5e9;color:#fff;font-weight:600;box-shadow:0 10px 24px rgba(0,0,0,.15);cursor:pointer}";
  document.head.appendChild(st);
  var w=document.createElement('div'); w.className="elbat-wrap";
  var b=document.createElement('button'); b.className="elbat-btn"; b.textContent="Chat med oss";
  b.addEventListener('click',function(){ window.open(BASE+"/","_blank"); });
  w.appendChild(b); document.body.appendChild(w);
  if (!window.__ELBATT_CHAT_API) window.__ELBATT_CHAT_API=BASE;
})();
JS
  echo "   -> Opprettet enkel embed.js"
else
  echo "   -> Fant eksisterende ${EMBED} ($(wc -c < "${EMBED}") bytes)"
fi
BASH
  chmod +x "${SCRIPTS_DIR}/fix-embed.sh"

  # 2) patch-embed-paths.sh (patch backend/main.py og Dockerfile)
  cat > "${SCRIPTS_DIR}/patch-embed-paths.sh" <<'BASH'
#!/usr/bin/env bash
set -Eeuo pipefail
say(){ printf "\n==> %s\n" "$*"; }
note(){ printf "   -> %s\n" "$*"; }

MAIN="backend/main.py"
DOCKERFILE="Dockerfile"
[ -f "${MAIN}" ] || { echo "Finner ikke ${MAIN}" >&2; exit 1; }

say "1) Patch ${MAIN} (ELBATT-EMBED blokk: health, static mount, /api/embed.js + /embed.js)"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("backend/main.py")
src = p.read_text(encoding="utf-8")

BEGIN = "# ELBATT-EMBED:BEGIN"
END   = "# ELBATT-EMBED:END"

# Fjern ev. gammel blokk
src = re.sub(re.compile(rf"{re.escape(BEGIN)}.*?{re.escape(END)}", re.S), "", src)

# NB: ren triple-quote streng (ikke f-string) for å unngå { } formateringsfeil
block = """
# ELBATT-EMBED:BEGIN
from pathlib import Path as _Path
try:
    app  # finnes app fra før?
except NameError:
    from fastapi import FastAPI as _FastAPI
    app = _FastAPI()

from fastapi.responses import FileResponse as _FileResponse
from fastapi.staticfiles import StaticFiles as _StaticFiles

# Health (GET/HEAD → 200/405 av FastAPI; GET er viktigst)
@app.get("/health")
def _elbatt_health():
    return {"status": "ok"}

# Statics
_app_dir = _Path(__file__).parent
_static_dir = _app_dir / "static"
try:
    app.mount("/static", _StaticFiles(directory=str(_static_dir)), name="static")
except Exception:
    pass

# embed.js – server fra /app/static/embed.js med cache headers
def _elbatt_embed_file_response():
    p = _static_dir / "embed.js"
    return _FileResponse(
        p,
        media_type="application/javascript",
        headers={"Cache-Control": "public, max-age=3600, immutable"},
    )

@app.get("/api/embed.js")
def _elbatt_embed_api():
    return _elbatt_embed_file_response()

@app.get("/embed.js")
def _elbatt_embed_root():
    return _elbatt_embed_file_response()
# ELBATT-EMBED:END
"""

# Legg blokken på slutten
src = src.rstrip() + "\n\n" + block.lstrip()

p.write_text(src, encoding="utf-8")
print("OK: backend/main.py oppdatert")
PY

say "2) Sørg for at Dockerfile kopierer static-katalogen"
if ! grep -qE 'COPY\s+backend/static\s+/app/static' "${DOCKERFILE}"; then
  note "legger til 'COPY backend/static /app/static'"
  # sett inn like etter 'COPY backend /app' om mulig, ellers append
  if grep -n 'COPY\s\+backend\s\+/app' "${DOCKERFILE}" >/dev/null; then
    awk '{
      print $0
      if ($0 ~ /COPY[[:space:]]+backend[[:space:]]+\/app/) {
        print "COPY backend/static /app/static"
        seen=1
      }
    } END { if (!seen) print "COPY backend/static /app/static" }' "${DOCKERFILE}" > "${DOCKERFILE}.new"
    mv "${DOCKERFILE}.new" "${DOCKERFILE}"
  else
    echo 'COPY backend/static /app/static' >> "${DOCKERFILE}"
  fi
else
  note "Dockerfile har allerede COPY backend/static /app/static"
fi

say "3) Python syntaks-sjekk"
python3 -m py_compile backend/main.py && echo "   -> OK"
BASH
  chmod +x "${SCRIPTS_DIR}/patch-embed-paths.sh"

  # 3) api-diagnose.sh (lokale tester)
  cat > "${SCRIPTS_DIR}/api-diagnose.sh" <<'BASH'
#!/usr/bin/env bash
set -Eeuo pipefail
SERVICE="${SERVICE:-api}"
PORT_TEST="${PORT_TEST:-8000}"

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "Finner ikke docker compose." >&2; exit 1
fi

echo "==> Container‑sjekk"
$COMPOSE ps
echo "==> Logs (siste 80 linjer)"
$COMPOSE logs --tail=80 "${SERVICE}" || true

echo "==> In‑container tester"
$COMPOSE exec -T "${SERVICE}" sh -lc '
  (apk add --no-cache curl >/dev/null 2>&1) || (apt-get update -y >/dev/null 2>&1 && apt-get install -y curl >/dev/null 2>&1) || true
  echo -n "GET /health: "; curl -sS http://127.0.0.1:8000/health | head -c 200; echo
  curl -sI http://127.0.0.1:8000/api/embed.js | sed -n "1p;/^content-type/I p;/^cache-control/I p"
'

echo "==> Host‑tester (hvis port er eksponert)"
if ss -lnt | awk '{print $4}' | grep -q ":${PORT_TEST}$"; then
  curl -sI "http://localhost:${PORT_TEST}/api/embed.js" | sed -n "1p;/^content-type/I p;/^cache-control/I p"
else
  echo "Port ${PORT_TEST} ikke eksponert – hopper over."
fi
BASH
  chmod +x "${SCRIPTS_DIR}/api-diagnose.sh"

  # 4) envoy-verify.sh (ekstern verifisering)
  cat > "${SCRIPTS_DIR}/envoy-verify.sh" <<'BASH'
#!/usr/bin/env bash
set -Eeuo pipefail
HOST="${HOST:-https://chatbot.elbatt.no}"
echo "==> Test ${HOST}/api/embed.js"
curl -sI "${HOST}/api/embed.js" | sed -n '1p;/^content-type/I p;/^cache-control/I p'
BASH
  chmod +x "${SCRIPTS_DIR}/envoy-verify.sh"

  # 5) diagnose-embed.sh (kort oppsummering lokalt/eksternt)
  cat > "${SCRIPTS_DIR}/diagnose-embed.sh" <<'BASH'
#!/usr/bin/env bash
set -Eeuo pipefail
say(){ printf "\n==> %s\n" "$*"; }
HOST="${HOST:-https://chatbot.elbatt.no}"

say "Lokal container-test"
curl -sI http://127.0.0.1:8000/api/embed.js | sed -n '1p;/^content-type/I p;/^cache-control/I p' || true

say "Offentlig test mot ${HOST}/api/embed.js"
curl -sI "${HOST}/api/embed.js" | sed -n '1p;/^content-type/I p;/^cache-control/I p' || true

say "Sjekk om Envoy finnes lokalt"
if docker ps | grep -Ei 'envoy' >/dev/null 2>&1; then
  echo "-> Envoy-container finnes her. Legg inn path‑rule for /api/embed.js → elbatt_api."
else
  echo "-> Ingen Envoy/container lokalt. Ruting styres av ekstern proxy/leverandør (f.eks. Mystore)."
fi

echo
echo "Konklusjon: Hvis lokalt=200 og eksternt=404 må proxy åpne /api/embed.js til samme upstream som /api/*."
BASH
  chmod +x "${SCRIPTS_DIR}/diagnose-embed.sh"

  # 6) make-inline-embed.sh (fallback for butikk)
  cat > "${SCRIPTS_DIR}/make-inline-embed.sh" <<'BASH'
#!/usr/bin/env bash
set -Eeuo pipefail
cat <<'HTML'
<!-- Midlertidig inline-versjon av embed mens proxy-route mangler -->
<script>
/*! elbatt inline embed */
(function(){
  if (window.__ElbattEmbedLoaded) return; window.__ElbattEmbedLoaded = true;
  var BASE='https://chatbot.elbatt.no';
  var st=document.createElement('style');
  st.textContent=".elbat-wrap{position:fixed;right:16px;bottom:16px;z-index:2147483000;font-family:system-ui,Roboto,Arial,sans-serif}.elbat-btn{border:0;border-radius:999px;padding:10px 14px;background:#0ea5e9;color:#fff;font-weight:600;box-shadow:0 10px 24px rgba(0,0,0,.15);cursor:pointer}";
  document.head.appendChild(st);
  var w=document.createElement('div'); w.className="elbat-wrap";
  var b=document.createElement('button'); b.className="elbat-btn"; b.textContent="Chat med oss";
  b.addEventListener('click',function(){ window.open(BASE+"/","_blank"); });
  w.appendChild(b); document.body.appendChild(w);
})();
</script>
HTML
BASH
  chmod +x "${SCRIPTS_DIR}/make-inline-embed.sh"

  # Liten “patch-pakke” for proxy som dokumentasjon
  cat > "${SCRIPTS_DIR}/envoy-patches.txt" <<'TXT'
# Legg inn én av disse i proxy/Envoy (samme upstream/cluster som /api/*):

# A) Direkte path-match:
- match: { path: "/api/embed.js" }
  route:
    cluster: elbatt_api
    timeout: 15s
    retry_policy: { retry_on: "5xx", num_retries: 2 }
    response_headers_to_add:
      - header: { key: "Cache-Control", value: "public, max-age=3600, immutable" }

# B) Hvis dere allerede rewrit’er /api/* til "/":
- match: { prefix: "/api/" }
  route:
    cluster: elbatt_api
    prefix_rewrite: "/"
    timeout: 15s

# Valgfritt speil, uten /api:
- match: { path: "/embed.js" }
  route: { cluster: elbatt_api, timeout: 15s }
TXT

  say "Installerer hjelpeskript i ./scripts/"
  note "Lagret proxy‑patcher i scripts/envoy-patches.txt"
  echo "✅ Hjelpeskript installert i ./scripts/"
}

# --- Build & start ---
do_build() {
  [ -n "${COMPOSE}" ] || { echo "Finner ikke docker compose/ docker-compose." >&2; exit 1; }

  say "Bygger og starter via Docker Compose"
  ${COMPOSE} up -d --build

  say "Container‑sjekk"
  ${COMPOSE} ps

  say "Korte tester"
  "${SCRIPTS_DIR}/api-diagnose.sh" || true
}

# --- All pipeline ---
do_all() {
  install_scripts

  say "Sikrer backend/static/embed.js"
  "${SCRIPTS_DIR}/fix-embed.sh"

  say "Patcher backend og Dockerfile"
  "${SCRIPTS_DIR}/patch-embed-paths.sh"

  do_build

  say "Ekstern verifisering"
  "${SCRIPTS_DIR}/envoy-verify.sh" || true

  echo
  echo "Hvis ekstern = 404, åpne route i proxy:"
  echo "  cat scripts/envoy-patches.txt"
  echo
  echo "Fallback (inline) om ønskelig:"
  echo "  ${SCRIPTS_DIR}/make-inline-embed.sh > inline-embed.html"
}

# --- Inline generation helper ---
do_inline() {
  "${SCRIPTS_DIR}/make-inline-embed.sh" > inline-embed.html
  echo "Skrev inline-embed.html (lim inn i butikk midlertidig)."
}

# --- Diagnose ---
do_diagnose() {
  "${SCRIPTS_DIR}/diagnose-embed.sh"
  "${SCRIPTS_DIR}/envoy-verify.sh" || true
}

# --- Entrypoint ---
case "${1:-all}" in
  install)  install_scripts ;;
  build)    do_build ;;
  diagnose) do_diagnose ;;
  inline)   do_inline ;;
  all|*)    do_all ;;
esac
