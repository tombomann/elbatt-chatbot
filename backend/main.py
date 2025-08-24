from fastapi import FastAPI
from . import security

app = FastAPI(title="Elbatt Chatbot API")
app = security.add_security(app)

@app.get("/health")
def health():
    return {"ok": True, "service": "elbatt-chatbot"}

# Eksempel-endepunkt for regnr (stub, koble til dine moduler)
@app.get("/api/regnr")
def regnr(q: str):
    # security.add_security har allerede validert formatet
    # Kall: vegvesen_lookup + varta scraping + product_match
    return {"ok": True, "regnr": q, "results": []}
