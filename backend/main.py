from fastapi import FastAPI, Query
from .playwright_varta import varta_lookup

app = FastAPI()

@app.get("/health")
def health(): return {"status":"ok"}

@app.get("/api/varta")
def api_varta(regnr: str = Query(..., min_length=2, max_length=10)):
    return varta_lookup(regnr)
