import os, re, asyncio
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Internal services (must exist in your project structure)
from services.cache import ttl_get, ttl_set
from services.vegvesen_lookup import vegvesen_lookup
from services.varta_lookup import varta_fast_lookup
from services.jobs import start_varta_playwright_job
from services.ai_chat import ai_answer

# ------------------------------------------------------------
# Config & App
# ------------------------------------------------------------
# Allowed origins (strict by default, can be widened via env)
DEFAULT_ALLOWED_ORIGINS = [
    "https://elbatt.no",
    "https://www.elbatt.no",
    "https://chatbot.elbatt.no",
]
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", ",").split(",") if os.getenv("ALLOWED_ORIGINS") else DEFAULT_ALLOWED_ORIGINS
CORS_ALLOW_ALL = os.getenv("CORS_ALLOW_ALL", "false").lower() == "true"

# Norwegian license plate pattern: two letters (incl. ÆØÅ) + 3-5 digits
PLATE_RE = re.compile(r"^[A-ZÅÆØ]{2}\d{3,5}$", re.IGNORECASE)

app = FastAPI(title="Elbatt Chatbot API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if CORS_ALLOW_ALL else ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET","POST","OPTIONS"],
    allow_headers=["Content-Type","Authorization"],
)

# ------------------------------------------------------------
# Models
# ------------------------------------------------------------
class ChatIn(BaseModel):
    message: str

class ChatOut(BaseModel):
    type: str
    data: Dict[str, Any]

# ------------------------------------------------------------
# Health
# ------------------------------------------------------------
@app.get("/health", include_in_schema=False)
def health() -> Dict[str, str]:
    return {"status": "ok"}

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
def norm_plate(p: str) -> str:
    p = p.strip().upper().replace(" ", "")
    if not PLATE_RE.match(p):
        raise HTTPException(400, "Ugyldig registreringsnummer")
    return p

# ------------------------------------------------------------
# Chat Endpoint
# ------------------------------------------------------------
@app.post("/api/chat", response_model=ChatOut)
async def chat(body: ChatIn, request: Request) -> ChatOut:
    msg = body.message.strip()

    # Plate detection path
    if PLATE_RE.match(msg.replace(" ", "")):
        plate = norm_plate(msg)
        cache_key = f"plate:{plate}"

        # Fast cached path
        cached: Optional[Dict[str, Any]] = ttl_get(cache_key)
        if cached:
            return ChatOut(type="plate", data={**cached, "cached": True})

        # Parallel lookups: Vegvesen + fast Varta (quick scrape/api)
        veg_task = asyncio.create_task(vegvesen_lookup(plate))
        varta_task = asyncio.create_task(varta_fast_lookup(plate, timeout=1.2))
        veg, varta = await asyncio.gather(veg_task, varta_task, return_exceptions=True)

        out: Dict[str, Any] = {"plate": plate}
        if not isinstance(veg, Exception) and veg is not None:
            out["vehicle"] = veg
        if not isinstance(varta, Exception) and varta is not None:
            out["varta"] = varta

        # Fire-and-forget: precise Playwright job for better accuracy
        asyncio.create_task(start_varta_playwright_job(plate))

        if not out.get("vehicle") and not out.get("varta"):
            # No usable data – temporary failure upstream
            raise HTTPException(status_code=502, detail="Oppslag feilet midlertidig")

        # Cache success path
        ttl_set(cache_key, out, ttl_seconds=1800)  # 30 min
        return ChatOut(type="plate", data=out)

    # Fallback to AI chat
    answer = await ai_answer(msg)
    return ChatOut(type="ai", data={"answer": answer})

# ------------------------------------------------------------
# Entrypoint (optional local run)
# ------------------------------------------------------------
if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
