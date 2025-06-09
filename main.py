from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

app = FastAPI()

@app.get("/")
async def status():
    return {"status": "Elbatt API kjører"}

@app.post("/lead")
async def motta_lead(request: Request):
    data = await request.json()
    # Her kan du utvide med Excel-logging, e-post osv.
    return JSONResponse({"received": data, "message": "Lead mottatt!"})
