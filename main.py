from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

app = FastAPI()

# Gjør hele public/ mappen tilgjengelig
app.mount("/", StaticFiles(directory="public", html=True), name="static")

# Ekstra sikkerhet for embed.js
@app.get("/embed.js")
async def get_embed():
    return FileResponse("public/embed.js", media_type="application/javascript")
