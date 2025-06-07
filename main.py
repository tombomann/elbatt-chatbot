from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Gjør public/ tilgjengelig for nettleseren på rot
app.mount("/", StaticFiles(directory="public", html=True), name="static")

