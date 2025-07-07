import os
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from starlette.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from backend.openai_service import call_openai_api
from backend.produktfeed import finn_produkt
from backend.faq import faq_match
from backend.logger import log_chat

# --- Miljøvariabler ---
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "https://elbatt.no,https://www.elbatt.no,https://chatbot.elbatt.no").split(",")
STATIC_DIR = os.getenv("STATIC_DIR", "/root/elbatt-chatbot/public")

# --- Pydantic models ---
class ChatRequest(BaseModel):
    message: str

class VegvesenRequest(BaseModel):
    regnr: str

# --- FastAPI app init ---
app = FastAPI(
    title="Elbatt Chatbot API",
    version="1.4",
    description="Chatbot-backend med OpenAI, Vegvesen, produktfeed og statiske filer",
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
        # 1. Svar på FAQ
        faq = faq_match(request.message)
        if faq:
            log_chat(user_id=user_id, message=request.message, response=faq)
            return {"response": faq}
        
        # 2. Svar fra produktfeed
        treff = finn_produkt(request.message)
        if treff:
            svar = "Her er produkter vi fant:<br>"
            for p in treff[:3]:
                svar += f"- <a href='{p['link']}' target='_blank'>{p['navn']}</a> – {p['pris']} kr<br>"
            log_chat(user_id=user_id, message=request.message, response=svar)
            return {"response": svar}

        # 3. Svar fra OpenAI
        response = await call_openai_api(request.message)
        log_chat(user_id=user_id, message=request.message, response=response)
        return {"response": response}

    except UnicodeEncodeError as e:
        feilmelding = f"Encoding error: {str(e)}"
        log_chat(user_id=user_id, message=request.message, response=feilmelding)
        raise HTTPException(status_code=500, detail=feilmelding)

    except Exception as e:
        log_chat(user_id=user_id, message=request.message, response=str(e))
        raise HTTPException(status_code=500, detail=f"Feil i chat-endepunktet: {str(e)}")

# --- Vegvesen API ---
@app.post("/api/vegvesen")
async def vegvesen_lookup(request: VegvesenRequest):
    try:
        data = await lookup_vehicle(request.regnr)
        felter = extract_vehicle_fields(data)
        if "error" in felter:
            raise Exception(felter["error"])
        # Formatér til ønsket chat-svar (markdown-style, klart for HTML/tekst)
        svar = (
            f"**Registrert:** {felter['registrert']}\n"
            f"**Bil:** {felter['merke']} {felter['modell']}\n"
            f"**Drivstoff:** {felter['drivstoff']}\n"
            f"**Motorkode:** {felter['motorkode']}\n"
            f"**Motorytelse:** {felter['motorytelse_kw']} kW"
            + (f" ({felter['motorytelse_hk']} hk)" if felter['motorytelse_hk'] else "")
        )
        return {"response": svar}
    except Exception as e:
        log_chat(user_id="anonym", message=request.regnr, response=str(e))
        raise HTTPException(status_code=500, detail=f"Vegvesen API-feil: {str(e)}")

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
