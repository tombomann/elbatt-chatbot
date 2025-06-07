from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Gjør public-mappen synlig (f.eks. test.html og embed.js)
app.mount("/", StaticFiles(directory="public", html=True), name="static")
