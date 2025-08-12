import os, httpx
from typing import Dict, Any
VEGVESEN_ENDPOINT = os.getenv("VEGVESEN_ENDPOINT","").rstrip("/")
VEGVESEN_API_KEY  = os.getenv("VEGVESEN_API_KEY","")

async def vegvesen_lookup(plate: str) -> Dict[str, Any]:
    if not VEGVESEN_ENDPOINT or not VEGVESEN_API_KEY: return {}
    headers = {"x-api-key": VEGVESEN_API_KEY, "accept": "application/json"}
    url = f"{VEGVESEN_ENDPOINT}/vehicles?registrationNumber={plate}"
    timeout = httpx.Timeout(2.0, connect=1.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        r = await client.get(url, headers=headers); r.raise_for_status()
        data = r.json()
        return {
            "raw": data,
            "brand": data.get("make") or data.get("merke"),
            "model": data.get("model") or data.get("modell"),
            "year":  data.get("year") or data.get("registreringsaar"),
            "fuel":  data.get("fuel") or data.get("drivstoff"),
        }
