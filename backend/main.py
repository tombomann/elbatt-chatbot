from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv
import os

# Laster inn .env-variabler automatisk
load_dotenv()

# Henter for eksempel OpenAI-nøkkel (og evt. andre API-nøkler)
openai_api_key = os.getenv("OPENAI_API_KEY")

# Importer funksjoner fra api_utils.py (du kan bygge ut!)
from api_utils import call_openai_api, log_lead, send_email

app = FastAPI()

# Server alle filer i public/ direkte på root
# app.mount("/", StaticFiles(directory="public", html=True), name="static")

# Test-endepunkt (for helsesjekk)
@app.get("/ping")
async def ping():
    return {"status": "ok"}

# Eksempel: Endepunkt for chatmeldinger (POST fra frontend/chat-widget)
@app.post("/api/chat")
async def chat(request: Request):
    data = await request.json()
    message = data.get("message")
    if not message:
        return JSONResponse({"error": "Melding mangler"}, status_code=400)

    # Kall OpenAI via api_utils (f.eks. med GPT-4)
    response = call_openai_api(message, api_key=openai_api_key)
    
    # Logg henvendelsen om ønskelig:
    # log_lead(message, svar=response)
    
    return {"response": response}

# Flere endepunkt kan legges til etter behov!
