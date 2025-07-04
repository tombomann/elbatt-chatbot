import os
import httpx

VEGVESEN_API_KEY = os.getenv("VEGVESEN_API_KEY")
if not VEGVESEN_API_KEY:
    raise RuntimeError("Mangler VEGVESEN_API_KEY i miljøvariabler.")

VEGVESEN_URL = "https://vegvesen.azure-api.net/vehicles/registreringsnummer/"

async def lookup_vehicle(regnr):
    headers = {
        "SVV-Authorization": VEGVESEN_API_KEY,
        "Accept": "application/json"
    }
    async with httpx.AsyncClient() as client:
        resp = await client.get(VEGVESEN_URL + regnr, headers=headers, timeout=8.0)
        resp.raise_for_status()
        return resp.json()
