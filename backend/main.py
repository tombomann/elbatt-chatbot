import os
import re
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from starlette.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
from dotenv import load_dotenv

# --- Importér tjenester ---
from backend.openai_service import call_openai_api
from backend.produktfeed import finn_produkt, start_background_updater
from backend.faq import faq_match
from backend.logger import log_chat
from backend.vegvesen_service import lookup_vehicle, format_vegvesen_svar
from backend.varta_service import varta_lookup

# --- Last inn miljøvariabler ---
load_dotenv(dotenv_path="/app/.env")

ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS",
    "https://elbatt.no,https://www.elbatt.no,https://chatbot.elbatt.no",
).split(",")
STATIC_DIR = os.getenv("STATIC_DIR", "/app/public")
ASSETS_DIR = os.getenv("ASSETS_DIR", "/app/assets")


# --- Pydantic-modeller ---
class ChatRequest(BaseModel):
    message: str


class VegvesenRequest(BaseModel):
    regnr: str


class VartaRequest(BaseModel):
    sporring: str


# --- Gjenkjenning av norsk bilnummer ---
def is_license_plate(msg):
    msg = msg.strip().upper().replace(" ", "")
    return bool(re.fullmatch(r"[A-ZÆØÅ]{2}\d{5}", msg))


# --- FastAPI-app ---
app = FastAPI(
    title="Elbatt Chatbot API",
    version="1.4",
    description="Chatbot-backend med OpenAI, Vegvesen, Varta, produktfeed, FAQ og statiske filer",
)

# --- CORS ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Health/ping ---
@app.get("/api/ping")
@app.get("/api/health")
def ping():
    return {"status": "ok"}


# --- Chat endpoint ---
@app.post("/api/chat")
async def chat(request: ChatRequest):
    user_id = "anonym"
    try:
        # 1. Bilnummer? Svar med Vegvesen-data først!
        if is_license_plate(request.message):
            data = await lookup_vehicle(request.message.replace(" ", ""))
            svar = format_vegvesen_svar(data)
            log_chat(user_id=user_id, message=request.message, response=svar)
            return {"response": svar}

        # 2. FAQ-svar
        faq = faq_match(request.message)
        if faq:
            log_chat(user_id=user_id, message=request.message, response=faq)
            return {"response": faq}

        # 3. Produktmatch
        treff = finn_produkt(request.message)
        if treff:
            svar = "Her er produkter vi fant:<br>"
            for p in treff[:3]:
                svar += f"- <a href='{p['link']}' target='_blank'>{p['navn']}</a> – {p['pris']} kr<br>"
            log_chat(user_id=user_id, message=request.message, response=svar)
            return {"response": svar}

        # 4. OpenAI fallback
        response = await call_openai_api(request.message)
        log_chat(user_id=user_id, message=request.message, response=response)
        return {"response": response}
    except Exception as e:
        log_chat(user_id=user_id, message=request.message, response=str(e))
        raise HTTPException(
            status_code=500, detail=f"Feil i chat-endepunktet: {str(e)}"
        )


# --- Vegvesen API direkte ---
@app.post("/api/vegvesen")
async def vegvesen_lookup(request: VegvesenRequest):
    try:
        data = await lookup_vehicle(request.regnr)
        svar = format_vegvesen_svar(data)
        log_chat(user_id="anonym", message=request.regnr, response=svar)
        return {"response": svar}
    except Exception as e:
        log_chat(user_id="anonym", message=request.regnr, response=str(e))
        raise HTTPException(status_code=500, detail=f"Vegvesen API-feil: {str(e)}")


# --- Varta scraping API ---
@app.post("/api/varta")
async def varta_api(request: VartaRequest):
    try:
        resultat = await varta_lookup(request.sporring)
        log_chat(user_id="anonym", message=request.sporring, response=resultat)
        return {"response": resultat}
    except Exception as e:
        log_chat(user_id="anonym", message=request.sporring, response=str(e))
        raise HTTPException(status_code=500, detail=f"Varta API-feil: {str(e)}")


# --- OpenAI API direkte ---
@app.post("/api/openai")
async def openai_api(request: ChatRequest):
    try:
        response = await call_openai_api(request.message)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OpenAI API-feil: {str(e)}")


# --- Exception handler for 404 (api) ---
@app.exception_handler(StarletteHTTPException)
async def custom_http_exception_handler(request: Request, exc: StarletteHTTPException):
    if exc.status_code == 404 and request.url.path.startswith("/api/"):
        return JSONResponse(status_code=404, content={"error": "Not found"})
    else:
        from fastapi.exception_handlers import http_exception_handler

        return await http_exception_handler(request, exc)


# --- Serve static files (public folder) ---
if os.path.exists(STATIC_DIR):
    app.mount("/", StaticFiles(directory=STATIC_DIR, html=True), name="static")

# --- Serve /assets/ (for bilder, f.eks. bilskilt) ---
if os.path.exists(ASSETS_DIR):
    app.mount("/assets", StaticFiles(directory=ASSETS_DIR), name="assets")
