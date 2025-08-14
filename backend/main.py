from fastapi.responses import FileResponse
import os, re, asyncio
from typing import Dict, Any
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

from services.cache import ttl_get, ttl_set
from services.vegvesen_lookup import vegvesen_lookup
from services.varta_lookup import varta_fast_lookup
from services.jobs import start_varta_playwright_job
from services.ai_chat import ai_answer

ALLOWED_ORIGINS = ["https://elbatt.no","https://www.elbatt.no","https://chatbot.elbatt.no"]
PLATE_RE = re.compile(r"^[A-ZÅÆØ]{2}\d{3,5}$", re.IGNORECASE)

app = FastAPI(title="Elbatt Chatbot API")
app.add_middleware(CORSMiddleware,
  allow_origins=ALLOWED_ORIGINS, allow_credentials=True,
  allow_methods=["GET","POST","OPTIONS"], allow_headers=["Content-Type","Authorization"])

class ChatIn(BaseModel): message: str
class ChatOut(BaseModel): type: str; data: Dict[str, Any]

@app.get("/health") def health(): return {"status": "ok"}

def norm_plate(p:str)->str:
    p=p.strip().upper().replace(" ","")
    if not PLATE_RE.match(p): raise HTTPException(400,"Ugyldig registreringsnummer")
    return p

@app.post("/api/chat", response_model=ChatOut)
async def chat(body: ChatIn, request: Request):
    msg = body.message.strip()
    if PLATE_RE.match(msg.replace(" ","")):
        plate = norm_plate(msg)
        cache_key = f"plate:{plate}"
        if (cached := ttl_get(cache_key)):
            return ChatOut(type="plate", data={**cached, "cached": True})

        # Parallelt: rask Varta + Vegvesen
        veg_task = asyncio.create_task(vegvesen_lookup(plate))
        varta_task = asyncio.create_task(varta_fast_lookup(plate, timeout=1.2))
        veg, varta = await asyncio.gather(veg_task, varta_task, return_exceptions=True)

        out: Dict[str, Any] = {"plate": plate}
        if not isinstance(veg, Exception): out["vehicle"] = veg
        if not isinstance(varta, Exception): out["varta"] = varta

        # Start Serverless Job i bakgrunnen for mer presis Playwright-scraping
        asyncio.create_task(start_varta_playwright_job(plate))

        if not out.get("vehicle") and not out.get("varta"):
            raise HTTPException(status_code=502, detail="Oppslag feilet midlertidig")
        ttl_set(cache_key, out, ttl_seconds=1800)
        return ChatOut(type="plate", data=out)

    # Ellers: AI-svar
    answer = await ai_answer(msg)
    return ChatOut(type="ai", data={"answer": answer})

# === EMBED_JS_ROUTE (auto) ===
@app.get("/embed.js")
def embed_js():
    path = os.getenv("EMBED_JS_PATH", "/app/public/embed.js")
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="embed.js not found")
    return FileResponse(path, media_type="application/javascript")
# === /EMBED_JS_ROUTE ===

# === CHAT_ALIAS (auto) ===
@app.post("/chat", response_model=ChatOut)
async def chat_alias(body: ChatIn, request: Request):
    return await chat(body, request)
# === /CHAT_ALIAS ===
