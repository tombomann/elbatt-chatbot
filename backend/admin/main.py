from fastapi import FastAPI

app = FastAPI(title="Elbatt Admin API")

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
