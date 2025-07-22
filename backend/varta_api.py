from fastapi import FastAPI, HTTPException
import asyncio
from playwright_varta import varta_lookup

app = FastAPI()

@app.get("/api/varta/health")
def health():
    return {"status": "ok"}

@app.get("/api/varta/{regnr}")
async def get_battery_code(regnr: str):
    result = await varta_lookup(regnr)
    if not result["battery_code"]:
        raise HTTPException(status_code=404, detail="Batterikode ikke funnet")
    return result
