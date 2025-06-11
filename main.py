from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Server alle filer i public/ direkte på root
app.mount("/", StaticFiles(directory="public", html=True), name="static")
