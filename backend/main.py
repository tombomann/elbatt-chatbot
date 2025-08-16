import os
from typing import Optional, Dict, Any, List
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

def _trim(v: Optional[str]) -> str:
    return (v or "").strip()

OPENAI_API_KEY = _trim(os.getenv("OPENAI_API_KEY"))
OPENAI_MODEL   = _trim(os.getenv("OPENAI_MODEL")) or "gpt-4o-mini"
OPENAI_ORG     = _trim(os.getenv("OPENAI_ORG"))
OPENAI_PROJECT = _trim(os.getenv("OPENAI_PROJECT"))  # ikke bruk sammen med user-keys

# Lazy import/klient
client = None
try:
    from openai import OpenAI
    if OPENAI_API_KEY:
        client = OpenAI(
            api_key=OPENAI_API_KEY,
            organization=OPENAI_ORG or None,
            project=OPENAI_PROJECT or None,
        )
except Exception:
    client = None

app = FastAPI(title="Elbatt Chatbot API")

# CORS
ALLOWED = (_trim(os.getenv("ALLOWED_ORIGINS")) or "https://elbatt.no,https://chatbot.elbatt.no").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in ALLOWED if o.strip()],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def _is_project_key(k: str) -> bool:
    # Kun eksplisitt 'sk-proj-' betyr prosjekt-nøkkel
    return k.startswith("sk-proj-")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/api/ping")
def api_ping():
    return {"status": "ok"}

@app.get("/api/_diag_env")
def diag_env():
    key = OPENAI_API_KEY or ""
    masked = (key[:5] + "*** len=" + str(len(key))) if key else "(missing)"
    return {
        "OPENAI_API_KEY": masked,
        "looks_like_sk": key.startswith("sk-"),
        "uses_project_key": _is_project_key(key),
        "OPENAI_ORG_set": bool(OPENAI_ORG),
        "OPENAI_PROJECT_set": bool(OPENAI_PROJECT),
        "OPENAI_MODEL": OPENAI_MODEL,
    }

@app.post("/api/chat")
def chat(payload: Dict[str, Any]):
    msg = (payload or {}).get("message", "").strip() or "Hei"
    if not client or not OPENAI_API_KEY:
        return {"type":"ai","data":{"answer":"Hei! Hvordan kan jeg hjelpe deg i dag?"}}
    try:
        r = client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {"role":"system","content":"Du er en hjelpsom norsk assistent."},
                {"role":"user","content": msg}
            ],
            temperature=0.3,
            max_tokens=200,
        )
        ans = (r.choices[0].message.content or "").strip()
        return {"type":"ai","data":{"answer": ans or "🤖"}}
    except Exception as e:
        return {"type":"ai","data":{"answer": f"(Feil mot modell: {e})"}}
