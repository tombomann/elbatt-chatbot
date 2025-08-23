import os, re, json
from typing import Dict, Any, Optional, List
import requests
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles

# --- Init ---
load_dotenv(override=False)
APP_VERSION = "elbatt-chatbot/1.1"

def _trim(s: Optional[str]) -> str:
    return (s or "").strip()

def ascii_sanitize(s: str) -> str:
    """Bytt ut problematiske Unicode-tegn med ASCII for trygg logging/JSON."""
    if not isinstance(s, str):
        s = str(s)
    replacements = {
        "\u2026": "...",  # ellipsis
        "’": "'", "‘": "'", "“": '"', "”": '"', "´": "'", "•": "-",
        "\u00a0": " ", "\u200b": "", "\u200c": "", "\u200d": "",
    }
    out = s
    for k, v in replacements.items():
        out = out.replace(k, v)
    try:
        out.encode("ascii")
        return out
    except Exception:
        return out.encode("ascii", "ignore").decode("ascii")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL   = ascii_sanitize(_trim(os.getenv("OPENAI_MODEL") or "gpt-4o-mini"))
OPENAI_ORG     = ascii_sanitize(_trim(os.getenv("OPENAI_ORG")))
OPENAI_PROJECT = ascii_sanitize(_trim(os.getenv("OPENAI_PROJECT")))
VEGVESEN_API_KEY = ascii_sanitize(_trim(os.getenv("VEGVESEN_API_KEY")))
DATA_FILE = ascii_sanitize(_trim(os.getenv("DATA_FILE") or "/app/data/products.xlsx"))
SQLITE_DB = ascii_sanitize(_trim(os.getenv("SQLITE_DB") or "/app/data/products.sqlite"))
GOOGLE_FEED_URL = ascii_sanitize(_trim(os.getenv("GOOGLE_FEED_URL") or "https://elbatt.no/twinxml/google_shopping.php"))

def mask_key_ascii(k: str) -> str:
    if not k:
        return "(missing)"
    L = len(k)
    if L <= 8:
        return k[:2] + "*** len=" + str(L)
    return k[:5] + "... len=" + str(L)

app = FastAPI(title="Elbatt API")

STATIC_DIR = os.environ.get("ELBATT_STATIC_DIR", "/app/static")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)

# Static mount (inne i imaget kopieres embed.js til /app/static)
app.mount("/static", StaticFiles(directory="/app/static"), name="static")

# ---------- Health ----------
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
        "OPENAI_API_KEY": mask_key_ascii(key),
        "looks_like_sk": key.startswith("sk-"),
        "uses_project_key": key.startswith("sk-proj-"),
        "OPENAI_ORG_set": bool(OPENAI_ORG),
        "OPENAI_PROJECT_set": bool(OPENAI_PROJECT),
        "OPENAI_MODEL": OPENAI_MODEL,
        "DATA_FILE_exists": os.path.exists(DATA_FILE),
        "SQLITE_exists": os.path.exists(SQLITE_DB),
        "VEGVESEN_API_KEY_set": bool(VEGVESEN_API_KEY),
    }

# ---------- Chat ----------
class ChatIn(BaseModel):
    message: str

@app.post("/api/chat")
def chat_api(inp: ChatIn):
    text = ascii_sanitize((inp.message or "").strip())
    if not text:
        return {"type":"ai","data":{"answer":"Skriv et spørsmål."}}
    try:
        if not OPENAI_API_KEY:
            return {"type":"ai","data":{"answer": f"(demo) Du sa: {text}"}}
        from openai import OpenAI
        client = OpenAI(api_key=OPENAI_API_KEY, organization=OPENAI_ORG or None, project=OPENAI_PROJECT or None)
        resp = client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[{"role":"user","content":text}],
            temperature=0.2,
        )
        answer = ascii_sanitize(resp.choices[0].message.content or "")
        return {"type":"ai","data":{"answer": answer}}
    except Exception as e:
        return {"type":"ai","data":{"answer": f"(Feil mot modell: {ascii_sanitize(str(e))})"}}

# ---------- Vegvesen ----------
def _vegvesen_headers(extra: Dict[str,str]) -> Dict[str,str]:
    base = {"Accept": "application/json", "User-Agent": APP_VERSION}
    base.update(extra)
    return base

@app.get("/api/vegvesen_lookup")
def vegvesen_lookup(kjennemerke: str = Query(..., min_length=2, max_length=10)):
    plate = ascii_sanitize(kjennemerke.strip().upper())
    if not VEGVESEN_API_KEY:
        return {"ok": False, "error": "VEGVESEN_API_KEY mangler (Secrets i container)."}
    url = "https://akfell-datautlevering.atlas.vegvesen.no/enkeltoppslag/kjoretoydata"
    params = {"kjennemerke": plate}
    variants = [
        _vegvesen_headers({"X-Env-ApiKey": VEGVESEN_API_KEY}),
        _vegvesen_headers({"X-API-Key": VEGVESEN_API_KEY}),
    ]
    last = None
    for hv in variants:
        try:
            r = requests.get(url, params=params, headers=hv, timeout=20)
            last = (r.status_code, hv)
            if r.status_code == 200:
                return {"ok": True, "data": r.json()}
            if r.status_code in (401,403):
                continue
            return {"ok": False, "error": f"HTTP {r.status_code}: {ascii_sanitize(r.text[:300])}"}
        except Exception as ex:
            last = ascii_sanitize(str(ex))
    return {"ok": False, "error": "401/403 fra Vegvesen – sjekk nøkkel/tilganger i Atlas", "debug": ascii_sanitize(str(last))}

# ---------- VARTA ----------
@app.get("/api/varta_lookup")
def varta_lookup(plateno: str = Query(..., min_length=2, max_length=10)):
    plate = ascii_sanitize(plateno.strip().upper())
    url = "https://www.varta-automotive.com/nb-no/batterisok"
    params = {"plateno": plate, "platelang": "nb-NO"}
    r = requests.get(url, params=params, timeout=30, headers={"User-Agent": APP_VERSION})
    html = r.text or ""
    kortkode = None
    m = re.search(r'Kortkode\s*[:=]\s*([A-Z0-9-]{3,})', html, re.I)
    if m: kortkode = m.group(1)
    return {"ok": True, "data": {"plateno": plate, "kortkode": kortkode, "length": len(html)}}

# ---------- Google feed (XML) ----------
@app.get("/api/google_feed_match")
def google_feed_match(q: str = Query(..., min_length=2)):
    import xmltodict
    query = ascii_sanitize(q.strip())
    if not GOOGLE_FEED_URL:
        return {"ok": False, "error": "GOOGLE_FEED_URL ikke satt"}
    r = requests.get(GOOGLE_FEED_URL, timeout=30, headers={"User-Agent": APP_VERSION})
    if r.status_code != 200:
        return {"ok": False, "error": f"HTTP {r.status_code} fra feed"}
    data = xmltodict.parse(r.text)
    items = data.get("rss", {}).get("channel", {}).get("item", []) or []
    if isinstance(items, dict): items = [items]
    ql = query.lower()
    hits = []
    for it in items:
        title = ascii_sanitize(it.get("title") or "")
        desc  = ascii_sanitize(it.get("description") or "")
        if ql in title.lower() or ql in desc.lower():
            hits.append({"title": title, "link": it.get("link"), "price": it.get("g:price")})
        if len(hits) >= 20: break
    return {"ok": True, "data": {"query": query, "count": len(hits), "items": hits}}

# ---------- EMBED.JS ----------
# Server både /embed.js og /api/embed.js (noen proxier tillater kun /api/*)
def _embed_response():
    resp = FileResponse("/app/static/embed.js", media_type="application/javascript")
    resp.headers["Cache-Control"] = "public, max-age=3600, immutable"
    resp.headers["Access-Control-Allow-Origin"] = "*"
    return resp

@app.get("/embed.js")
def embed_root_get():
    return _embed_response()

@app.head("/embed.js")
def embed_root_head():
    return Response(status_code=200, media_type="application/javascript", headers={
        "Cache-Control": "public, max-age=3600, immutable",
        "Access-Control-Allow-Origin": "*",
    })

@app.get("/api/embed.js")
def embed_api_get():
    return _embed_response()

@app.head("/api/embed.js")
def embed_api_head():
    return Response(status_code=200, media_type="application/javascript", headers={
        "Cache-Control": "public, max-age=3600, immutable",
        "Access-Control-Allow-Origin": "*",
    })


# === EMBED STATIC ROUTES (auto) ===
# Monter /static (tåler å feile hvis allerede montert)
try:
    app.mount("/static", StaticFiles(directory="/app/static"), name="static")
except Exception:
    pass

def _embed_headers():
    return {
        "Cache-Control": "public, max-age=3600, immutable",
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/javascript",
    }

@app.get("/api/embed.js")
def _get_embed_api():
    return FileResponse("/app/static/embed.js", media_type="application/javascript", headers=_embed_headers())

@app.head("/api/embed.js")
def _head_embed_api():
    return Response(status_code=200, headers=_embed_headers())

@app.get("/embed.js")
def _get_embed_root():
    return FileResponse("/app/static/embed.js", media_type="application/javascript", headers=_embed_headers())

@app.head("/embed.js")
def _head_embed_root():
    return Response(status_code=200, headers=_embed_headers())
# === END EMBED STATIC ROUTES ===


# === EMBED ROUTES START ===
def _embed_headers():
    return {"Cache-Control": "public, max-age=3600, immutable",
            "Access-Control-Allow-Origin": "*"}

@app.get("/api/embed.js")
def get_embed_api():
    import os
    return FileResponse(os.path.join(STATIC_DIR, "embed.js"),
                        media_type="application/javascript",
                        headers=_embed_headers())

@app.head("/api/embed.js")
def head_embed_api():
    return Response(status_code=200, media_type="application/javascript",
                    headers=_embed_headers())

@app.get("/embed.js")
def get_embed():
    import os
    return FileResponse(os.path.join(STATIC_DIR, "embed.js"),
                        media_type="application/javascript",
                        headers=_embed_headers())

@app.head("/embed.js")
def head_embed():
    return Response(status_code=200, media_type="application/javascript",
                    headers=_embed_headers())
# === EMBED ROUTES END ===


@app.get("/api/embed.js")
def get_embed_js_api():
    headers = {"Cache-Control": "public, max-age=3600, immutable"}
    return FileResponse("/app/static/embed.js", media_type="application/javascript", headers=headers)


@app.get("/embed.js")
def get_embed_js_root():
    headers = {"Cache-Control": "public, max-age=3600, immutable"}
    return FileResponse("/app/static/embed.js", media_type="application/javascript", headers=headers)

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
