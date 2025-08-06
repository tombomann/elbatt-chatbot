from fastapi import FastAPI
import uvicorn

app = FastAPI(title="Elbatt Chatbot API")


@app.get("/api/health")
async def health_check():
    return {"status": "ok", "feed_items": 978}


@app.head("/api/health")
async def health_check_head():
    return {"status": "ok", "feed_items": 978}


@app.get("/")
async def root():
    return {"message": "Elbatt Chatbot API is running!"}


@app.head("/")
async def root_head():
    return {}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000)
