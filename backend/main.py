from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from dotenv import load_dotenv
from pydantic import BaseModel

# Last miljøvariabler
load_dotenv()

app = FastAPI(title="Elbatt Chatbot API")

# Legg til CORS-middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modell for chat-meldinger
class ChatMessage(BaseModel):
    message: str

@app.get("/")
async def root():
    return {"message": "Elbatt Chatbot API"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.post("/api/chat")
async def chat(chat_message: ChatMessage):
    try:
        message = chat_message.message
        # Her ville du normalt kalle en AI-tjeneste
        # For nå, returnerer vi en enkel svar
        return {"response": f"Jeg mottok meldingen: {message}"}
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
