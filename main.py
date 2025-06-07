from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
import os

app = FastAPI()

# Sørg for at hele public/ eksponeres korrekt
app.mount("/public", StaticFiles(directory="public"), name="public")

# Eksakt rute for embed.js
@app.get("/embed.js")
async def get_embed():
    file_path = os.path.join("public", "embed.js")
    return FileResponse(file_path, media_type="application/javascript")

# (valgfritt) testside
@app.get("/test-chatbot.html")
async def get_test():
    return FileResponse("public/test-chatbot.html", media_type="text/html")
