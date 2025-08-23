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
