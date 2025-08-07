from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
import os
from typing import Optional

app = FastAPI(title="Elbatt Chatbot API", version="1.0.0")


class ChatMessage(BaseModel):
    message: str
    session_id: Optional[str] = None


@app.get("/api/health")
async def health_check():
    return {"status": "ok", "feed_items": 978}


@app.head("/api/health")
async def health_check_head():
    return {"status": "ok", "feed_items": 978}


@app.post("/api/chat")
async def chat_endpoint(chat_message: ChatMessage):
    try:
        user_message = chat_message.message

        # Hent API-nøkler fra environment
        openai_api_key = os.getenv("OPENAI_API_KEY")
        vegvesen_api_key = os.getenv("VEGVESEN_API_KEY")

        # Enkel respons for testing
        if "test" in user_message.lower():
            return {
                "response": "Dette er en testrespons fra Elbatt Chatbot!",
                "status": "success",
            }

        # Sjekk om det er en henvendelse om batteri
        if "batteri" in user_message.lower() or "elbil" in user_message.lower():
            return {
                "response": "Jeg kan hjelpe deg med informasjon om elbilbatterier. Hva lurer du spesifikt på?",
                "status": "success",
            }

        # Sjekk om det er en henvendelse om Vegvesen
        if "vegvesen" in user_message.lower() or "registrering" in user_message.lower():
            return {
                "response": "Jeg kan slå opp informasjon i Vegvesenets register. Hvilken bil er det snakk om?",
                "status": "success",
            }

        # Standard respons
        return {
            "response": "Jeg er Elbatt Chatbot! Jeg kan hjelpe deg med informasjon om elbatterier, bilinfo fra Vegvesenet, og generelle spørsmål om elbiler. Hvordan kan jeg hjelpe deg i dag?",
            "status": "success",
        }

    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Error processing message: {str(e)}"
        )


@app.get("/")
async def root():
    return {"message": "Elbatt Chatbot API is running!"}


@app.head("/")
async def root_head():
    return {}


@app.post("/api/vegvesen")
async def vegvesen_lookup(data: dict):
    registration_number = data.get("registration_number", "")
    if not registration_number:
        raise HTTPException(status_code=400, detail="Registration number is required")

    # Simulerer Vegvesen-oppslag
    return {
        "registration_number": registration_number,
        "vehicle_info": {
            "make": "Tesla",
            "model": "Model 3",
            "year": 2023,
            "battery_capacity": "75 kWh",
        },
        "status": "success",
    }


@app.post("/api/varta")
async def varta_search(data: dict):
    product_type = data.get("product_type", "")
    vehicle_model = data.get("vehicle_model", "")

    # Simulerer Varta-produktsøk
    return {
        "products": [
            {
                "name": "Varta Battery for Tesla Model 3",
                "type": product_type,
                "compatible": True,
                "price": "NOK 45,000",
            }
        ],
        "status": "success",
    }


@app.get("/check-env")
async def check_env():
    return {
        "openai_key_set": bool(os.getenv("OPENAI_API_KEY")),
        "vegvesen_key_set": bool(os.getenv("VEGVESEN_API_KEY")),
        "langflow_key_set": bool(os.getenv("LANGFLOW_API_KEY")),
        "var1": os.getenv("VAR1"),
        "var2": os.getenv("VAR2"),
    }


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
