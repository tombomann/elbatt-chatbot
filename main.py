from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Eksponer public-mappe korrekt
app.mount("/public", StaticFiles(directory="public"), name="public")

# Spesifikk rute for embed.js
@app.get("/embed.js")
async def get_embed():
    return FileResponse("public/embed.js", media_type="application/javascript")
