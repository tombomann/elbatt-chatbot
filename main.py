from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

app = FastAPI()

app.mount("/", StaticFiles(directory="public", html=True), name="static")

@app.get("/embed.js")
async def get_embed():
    return FileResponse("public/embed.js", media_type="application/javascript")
