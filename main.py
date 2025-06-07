from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Gjør public-mappen tilgjengelig for nettleseren
app.mount("/", StaticFiles(directory="public", html=True), name="static")
