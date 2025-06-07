from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Gjør public/ tilgjengelig som statiske filer
app.mount("/public", StaticFiles(directory="public"), name="public")

# Eksplisitt route for /embed.js
@app.get("/embed.js")
async def get_embed():
    return FileResponse("public/embed.js", media_type="application/javascript")

# En enkel test på / så du vet at serveren kjører
@app.get("/")
def read_root():
    return {"status": "OK", "message": "Elbatt chatbot API works!"}
