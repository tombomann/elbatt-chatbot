# backend/vegvesen_lookup.py
import os
import time
from typing import Any, Dict, Optional, Tuple
import httpx

VEGVESEN_ENDPOINT = os.getenv(
    "VEGVESEN_ENDPOINT",
    "https://www.vegvesen.no/ws/no/vegvesen/kjoretoy/felles/datautlevering/enkeltoppslag/kjoretoydata",
)
VEGVESEN_API_KEY = os.getenv("VEGVESEN_API_KEY", "")

# Superenkel TTL-cache i minne (per prosess)
_CACHE: Dict[str, Tuple[float, Dict[str, Any]]] = {}
TTL_SECONDS = int(os.getenv("VEGVESEN_TTL_SECONDS", "300"))

class VegvesenError(Exception):
    def __init__(self, status: int, message: str):
        self.status = status
        self.message = message
        super().__init__(f"{status}: {message}")

async def fetch_plate(plate: str) -> Dict[str, Any]:
    if not VEGVESEN_API_KEY:
        raise VegvesenError(500, "VEGVESEN_API_KEY mangler")

    now = time.time()
    hit = _CACHE.get(plate)
    if hit and (now - hit[0]) < TTL_SECONDS:
        return hit[1]

    url = f"{VEGVESEN_ENDPOINT}?kjennemerke={plate}"
    headers = {
        "SVV-Authorization": f"Apikey {VEGVESEN_API_KEY}",
        "Accept": "application/json",
    }

    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.get(url, headers=headers)
        if resp.status_code == 200:
            data = resp.json()
            _CACHE[plate] = (now, data)
            return data
        elif resp.status_code == 401:
            raise VegvesenError(401, "Unauthorized – sjekk at nøkkelen har Enkeltoppslag-tilgang")
        elif resp.status_code == 403:
            raise VegvesenError(403, "Forbidden – IP/tilgang kan mangle i oppsett hos Vegvesenet")
        elif resp.status_code == 404:
            raise VegvesenError(404, "Ikke funnet – sjekk 'kjennemerke'")
        else:
            raise VegvesenError(resp.status_code, resp.text)

def extract_basic_specs(payload: Dict[str, Any]) -> Dict[str, Optional[str]]:
    """Dra ut nyttige felt til Varta/produktmatch (merke, modell, motorkode m.m.)."""
    try:
        item = payload["kjoretoydataListe"][0]
        tg = item["godkjenning"]["tekniskGodkjenning"]["tekniskeData"]
        generelt = tg["generelt"]
        merke = (generelt.get("merke") or [{}])[0].get("merke")
        handelsbetegnelse = (generelt.get("handelsbetegnelse") or [""])[0]
        typebetegnelse = generelt.get("typebetegnelse")
        motor = (tg.get("motorOgDrivverk", {}).get("motor") or [{}])[0]
        motorkode = motor.get("motorKode")
        drivstoff = (motor.get("drivstoff") or [{}])[0]
        effekt_kw = drivstoff.get("maksNettoEffekt")
        return {
            "merke": merke,
            "modell": handelsbetegnelse,
            "typebetegnelse": typebetegnelse,
            "motorkode": motorkode,
            "effekt_kw": str(effekt_kw) if effekt_kw is not None else None,
        }
    except Exception:
        return {"merke": None, "modell": None, "typebetegnelse": None, "motorkode": None, "effekt_kw": None}
