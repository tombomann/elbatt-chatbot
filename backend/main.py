from fastapi import FastAPI, Body
from health import router as health_router

app = FastAPI()
# health: /api/ping (brukes av verify-script)
app.include_router(health_router, prefix="/api", tags=["health"])

# enkel ekko-chat: /api/chat
@app.post("/api/chat")
async def chat(payload: dict = Body(...)):
    msg = payload.get("message","")
    return {"type":"ai","data":{"answer":f"Du skrev: {msg}"}}
