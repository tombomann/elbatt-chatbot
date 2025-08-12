from __future__ import annotations

import os
import json
import asyncio
from datetime import datetime
from typing import List, Optional

import redis
from fastapi import (
    FastAPI,
    HTTPException,
    Depends,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Elbatt Admin Dashboard", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

redis_available = False
redis_client: Optional[redis.Redis] = None
try:
    redis_client = redis.Redis(
        host=os.getenv("REDIS_HOST", "localhost"),
        port=int(os.getenv("REDIS_PORT", "6379")),
        db=int(os.getenv("REDIS_DB", "0")),
        decode_responses=True,
    )
    redis_client.ping()
    redis_available = True
except Exception:
    print("Redis ikke tilgjengelig, bruker minne-lagring")
    redis_available = False

security = HTTPBearer()
ADMIN_TOKEN_DEFAULT = "admin-secret"


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    if credentials.credentials != os.getenv("ADMIN_TOKEN", ADMIN_TOKEN_DEFAULT):
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")
    return {"user": "admin"}


class CustomerMessage(BaseModel):
    id: str
    customer_id: str
    message: str
    timestamp: str
    status: str = "unread"
    session_id: str


class AdminResponse(BaseModel):
    message_id: str
    response: str
    admin_id: str


class ProjectMetrics(BaseModel):
    total_messages: int
    active_sessions: int
    response_time: float
    system_status: str


class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        try:
            self.active_connections.remove(websocket)
        except ValueError:
            pass

    async def broadcast(self, message: str):
        tasks = [self._safe_send(ws, message) for ws in list(self.active_connections)]
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)

    @staticmethod
    async def _safe_send(ws: WebSocket, msg: str):
        try:
            await ws.send_text(msg)
        except Exception:
            try:
                await ws.close()
            except Exception:
                pass


manager = ConnectionManager()

mock_messages: List[dict] = [
    {
        "id": "1",
        "customer_id": "customer_1",
        "message": "Hvilket batteri passer til min Tesla Model 3?",
        "timestamp": "2025-08-07T10:00:00",
        "status": "unread",
        "session_id": "session_1",
    },
    {
        "id": "2",
        "customer_id": "customer_2",
        "message": "Hva er leveringstiden for Varta batterier?",
        "timestamp": "2025-08-07T10:30:00",
        "status": "read",
        "session_id": "session_2",
    },
]

mock_sessions: List[dict] = [
    {
        "id": "session_1",
        "customer_id": "customer_1",
        "start_time": "2025-08-07T09:00:00",
        "last_activity": "2025-08-07T10:00:00",
        "message_count": 3,
    },
    {
        "id": "session_2",
        "customer_id": "customer_2",
        "start_time": "2025-08-07T09:30:00",
        "last_activity": "2025-08-07T10:30:00",
        "message_count": 2,
    },
]

@app.get("/health", include_in_schema=False)
def health_root():
    return {"status": "healthy"}

@app.get("/api/health", include_in_schema=False)
async def health_api():
    return {"status": "healthy", "service": "admin-dashboard"}

@app.get("/api/admin/messages", response_model=List[CustomerMessage])
async def get_messages(user: dict = Depends(get_current_user)):
    if redis_available and redis_client:
        messages: List[dict] = []
        for key in redis_client.scan_iter(match="message:*"):
            data = redis_client.get(key)
            if data:
                try:
                    messages.append(json.loads(data))
                except Exception:
                    pass
        return sorted(messages, key=lambda x: x.get("timestamp", ""), reverse=True)
    else:
        return sorted(mock_messages, key=lambda x: x.get("timestamp", ""), reverse=True)

@app.post("/api/admin/messages/{message_id}/read")
async def mark_message_read(message_id: str, user: dict = Depends(get_current_user)):
    if redis_available and redis_client:
        key = f"message:{message_id}"
        data = redis_client.get(key)
        if not data:
            raise HTTPException(status_code=404, detail="Message not found")
        message = json.loads(data)
        message["status"] = "read"
        redis_client.set(key, json.dumps(message))
        return {"status": "success"}
    else:
        for m in mock_messages:
            if m["id"] == message_id:
                m["status"] = "read"
                return {"status": "success"}
        raise HTTPException(status_code=404, detail="Message not found")

@app.post("/api/admin/respond")
async def respond_to_customer(response: AdminResponse, user: dict = Depends(get_current_user)):
    payload = {
        "message_id": response.message_id,
        "response": response.response,
        "admin_id": response.admin_id,
        "timestamp": datetime.now().isoformat(),
    }
    if redis_available and redis_client:
        redis_client.set(f"response:{response.message_id}", json.dumps(payload))
    else:
        print(f"Response stored (mock): {payload}")
    await manager.broadcast(json.dumps({"type": "new_response", "data": payload}))
    return {"status": "success"}

@app.get("/api/admin/metrics", response_model=ProjectMetrics)
async def get_metrics(user: dict = Depends(get_current_user)):
    if redis_available and redis_client:
        total_messages = len(list(redis_client.scan_iter(match="message:*")))
        active_sessions = len(list(redis_client.scan_iter(match="session:*")))
    else:
        total_messages = len(mock_messages)
        active_sessions = len(mock_sessions)
    return ProjectMetrics(
        total_messages=total_messages,
        active_sessions=active_sessions,
        response_time=2.5,
        system_status="healthy",
    )

@app.get("/api/admin/sessions")
async def get_active_sessions(user: dict = Depends(get_current_user)):
    if redis_available and redis_client:
        sessions: List[dict] = []
        for key in redis_client.scan_iter(match="session:*"):
            data = redis_client.get(key)
            if data:
                try:
                    sessions.append(json.loads(data))
                except Exception:
                    pass
        return sessions
    else:
        return mock_sessions

@app.websocket("/ws/admin")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            _ = await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8002"))
    uvicorn.run(app, host="0.0.0.0", port=port)
