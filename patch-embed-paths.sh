#!/usr/bin/env bash
set -Eeuo pipefail

say(){ printf "\n==> %s\n" "$*"; }
note(){ printf "   -> %s\n" "$*"; }

MAIN="backend/main.py"
DOCKERFILE="Dockerfile"

[ -f "${MAIN}" ] || { echo "Finner ikke ${MAIN}" >&2; exit 1; }

say "1) Patch ${MAIN} (imports, statisk mount, /api/embed.js og /embed.js)"
python3 - <<'PY'
from pathlib import Path
import re

p = Path("backend/main.py")
s = p.read_text(encoding="utf-8")

def ensure(line: str, anchor: str, where="before"):
    global s
    if line in s: return
    if anchor in s:
        if where == "before":
            s = s.replace(anchor, line+"\n"+anchor)
        else:
            s = s.replace(anchor, anchor+"\n"+line)
    else:
        s = line + "\n" + s

# 1) Imports
ensure("from fastapi.staticfiles import StaticFiles", "from dotenv import load_dotenv", "after")
if "from fastapi.responses import FileResponse" in s and "Response" not in s:
    s = s.replace("from fastapi.responses import FileResponse", "from fastapi.responses import FileResponse, Response")
elif "from fastapi.responses import FileResponse, Response" not in s:
    ensure("from fastapi.responses import FileResponse, Response", "from dotenv import load_dotenv", "after")

# 2) Mount static (/app/static inside container)
mount_snippet = 'app.mount("/static", StaticFiles(directory="/app/static"), name="static")'
if mount_snippet not in s:
    # finn første "app =" linje og legg mount etterpå
    m = re.search(r'^\s*app\s*=\s*FastAPI\([^)]*\)\s*$', s, flags=re.M)
    if m:
        idx = m.end()
        s = s[:idx] + "\n" + mount_snippet + s[idx:]
    else:
        # Fallback: legg på slutten
        s += "\n" + mount_snippet + "\n"

# 3) /api/embed.js route med cache-headere
route_api = """
@app.get("/api/embed.js")
def get_embed_js_api():
    headers = {"Cache-Control": "public, max-age=3600, immutable"}
    return FileResponse("/app/static/embed.js", media_type="application/javascript", headers=headers)
""".strip()

if 'def get_embed_js_api()' not in s:
    # Legg før siste router-filter (eller på slutten)
    s += "\n\n" + route_api + "\n"

# 4) Valgfri /embed.js (speil)
route_root = """
@app.get("/embed.js")
def get_embed_js_root():
    headers = {"Cache-Control": "public, max-age=3600, immutable"}
    return FileResponse("/app/static/embed.js", media_type="application/javascript", headers=headers)
""".strip()

if 'def get_embed_js_root()' not in s:
    s += "\n\n" + route_root + "\n"

Path("backend/main.py").write_text(s, encoding="utf-8")
print("OK: backend/main.py oppdatert")
PY

say "2) Sørg for at Dockerfile kopierer static-katalogen"
if grep -qE '^\s*COPY\s+backend/static\s+/app/static\s*$' "${DOCKERFILE}"; then
  note "Dockerfile har allerede COPY backend/static /app/static"
else
  # Legg COPY-linje etter første 'COPY backend /app' hvis den finnes, ellers på slutten
  if grep -qE '^\s*COPY\s+backend\s+/app\s*$' "${DOCKERFILE}"; then
    awk '{
      print $0;
      if (!added && $0 ~ /^\s*COPY\s+backend\s+\/app\s*$/) { print "COPY backend/static /app/static"; added=1 }
    } END { if (!added) print "COPY backend/static /app/static" }' "${DOCKERFILE}" > "${DOCKERFILE}.tmp"
    mv "${DOCKERFILE}.tmp" "${DOCKERFILE}"
    note "La til COPY backend/static /app/static rett etter COPY backend /app"
  else
    printf "\nCOPY backend/static /app/static\n" >> "${DOCKERFILE}"
    note "La til COPY backend/static /app/static på slutten av Dockerfile"
  fi
fi

say "3) Syntaks-sjekk av Python"
python3 -m pyflakes backend/main.py >/dev/null 2>&1 || true
python3 - <<'PY'
import ast,sys
ast.parse(open("backend/main.py","rb").read())
print("   -> Python OK")
PY
