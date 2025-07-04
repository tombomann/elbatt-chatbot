import os
import time
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from starlette.responses import JSONResponse
from starlette.status import HTTP_404_NOT_FOUND

# --- Import backend-tjenester ---
from backend.openai_service import call_openai_api  # Henter API-nøkkel fra env
from backend.vegvesen_service import lookup_vehicle  # Henter API-nøkkel fra env
from backend.produktfeed import finn_produkt  # Produktfeed/cache


# --- Pydantic-modeller ---
class ChatRequest(BaseModel):
    message: str


class VegvesenRequest(BaseModel):
    regnr: str


# --- App-setup ---
app = FastAPI(
    title="Elbatt Chatbot API",
    version="1.3",
    description="Chatbot-backend med OpenAI, Vegvesen, produktfeed og statiske filer",
)

# --- CORS (tillat bare domener du stoler på) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://elbatt.no",
        "https://www.elbatt.no",
        "https://chatbot.elbatt.no",
        "https://elbatt-test.netlify.app",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- API endpoints under /api/ ---
@app.get("/api/ping")
def ping():
    return {"status": "ok"}


@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.post("/api/chat")
async def chat(request: ChatRequest):
    try:
        # 1. Prøv produktmatch (cachet fra XML-feed)
        treff = finn_produkt(request.message)
        if treff:
            svar = "Her er produkter vi fant:<br>"
            for p in treff[:3]:
                svar += f"- <a href='{p['link']}' target='_blank'>{p['navn']}</a> – {p['pris']} kr<br>"
            return {"response": svar}
        # 2. Hvis ingen treff, bruk OpenAI
        response = await call_openai_api(request.message)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"API-feil: {e}")


@app.post("/api/vegvesen")
async def vegvesen_lookup(request: VegvesenRequest):
    try:
        data = await lookup_vehicle(request.regnr)
        return {"data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Vegvesen API-feil: {e}")


# --- API 404 handler (JSON for /api/, ellers statisk) ---
@app.exception_handler(404)
async def api_not_found(request: Request, exc):
    if str(request.url.path).startswith("/api/"):
        return JSONResponse(status_code=404, content={"error": "Not found"})
    return await app.default_exception_handler(request, exc)


# --- Serve statiske filer fra /public ---
app.mount(
    "/", StaticFiles(directory="/root/elbatt-chatbot/public", html=True), name="static"
)
