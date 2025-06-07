from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Gjør public/ tilgjengelig som statiske filer
app.mount("/", StaticFiles(directory="public", html=True), name="static")
