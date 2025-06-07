from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Gjør hele "public/" synlig
app.mount("/", StaticFiles(directory="public", html=True), name="static")

# Eksplisitt rute for embed.js
@app.get("/embed.js")
async def get_embed():
    return FileResponse("public/embed.js", media_type="application/javascript")
