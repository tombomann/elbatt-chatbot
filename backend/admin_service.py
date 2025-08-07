from fastapi import FastAPI, HTTPException, Depends, WebSocket, WebSocketDisconnect
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import json
import asyncio
from datetime import datetime
import redis
import os

app = FastAPI(title="Elbatt Admin Dashboard", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Redis connection
try:
    redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
    redis_client.ping()
    redis_available = True
except:
    redis_available = False
    print("Redis ikke tilgjengelig, bruker minne-lagring")

# Security
security = HTTPBearer()

# Models
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
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except:
                pass

manager = ConnectionManager()

# Authentication
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    # Simple token validation - in production, use proper JWT
    if credentials.credentials != os.getenv("ADMIN_TOKEN", "admin-secret"):
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")
    return {"user": "admin"}

# Mock data storage (in production, use Redis or database)
mock_messages = [
    {
        "id": "1",
        "customer_id": "customer_1",
        "message": "Hvilket batteri passer til min Tesla Model 3?",
        "timestamp": "2025-08-07T10:00:00",
        "status": "unread",
        "session_id": "session_1"
    },
    {
        "id": "2", 
        "customer_id": "customer_2",
        "message": "Hva er leveringstiden for Varta batterier?",
        "timestamp": "2025-08-07T10:30:00",
        "status": "read",
        "session_id": "session_2"
    }
]

mock_sessions = [
    {
        "id": "session_1",
        "customer_id": "customer_1",
        "start_time": "2025-08-07T09:00:00",
        "last_activity": "2025-08-07T10:00:00",
        "message_count": 3
    },
    {
        "id": "session_2",
        "customer_id": "customer_2", 
        "start_time": "2025-08-07T09:30:00",
        "last_activity": "2025-08-07T10:30:00",
        "message_count": 2
    }
]

# API Endpoints
@app.get("/api/health")
async def health_check():
    return {"status": "healthy", "service": "admin-dashboard"}

@app.get("/api/admin/messages", response_model=List[CustomerMessage])
async def get_messages(user: dict = Depends(get_current_user)):
    """Get all customer messages"""
    if redis_available:
        messages = []
        for key in redis_client.scan_iter(match="message:*"):
            message_data = redis_client.get(key)
            if message_data:
                messages.append(json.loads(message_data))
        return sorted(messages, key=lambda x: x['timestamp'], reverse=True)
    else:
        return mock_messages

@app.post("/api/admin/messages/{message_id}/read")
async def mark_message_read(message_id: str, user: dict = Depends(get_current_user)):
    """Mark a message as read"""
    if redis_available:
        message_key = f"message:{message_id}"
        message_data = redis_client.get(message_key)
        if message_data:
            message = json.loads(message_data)
            message['status'] = 'read'
            redis_client.set(message_key, json.dumps(message))
            return {"status": "success"}
        raise HTTPException(status_code=404, detail="Message not found")
    else:
        for message in mock_messages:
            if message['id'] == message_id:
                message['status'] = 'read'
                return {"status": "success"}
        raise HTTPException(status_code=404, detail="Message not found")

@app.post("/api/admin/respond")
async def respond_to_customer(response: AdminResponse, user: dict = Depends(get_current_user)):
    """Send response to customer"""
    # Store response in Redis or mock storage
    response_data = {
        "message_id": response.message_id,
        "response": response.response,
        "admin_id": response.admin_id,
        "timestamp": datetime.now().isoformat()
    }
    
    if redis_available:
        redis_client.set(f"response:{response.message_id}", json.dumps(response_data))
    else:
        print(f"Response stored: {response_data}")
    
    # Broadcast to WebSocket connections
    await manager.broadcast(json.dumps({
        "type": "new_response",
        "data": response_data
    }))
    
    return {"status": "success"}

@app.get("/api/admin/metrics", response_model=ProjectMetrics)
async def get_metrics(user: dict = Depends(get_current_user)):
    """Get project metrics"""
    if redis_available:
        total_messages = len(list(redis_client.scan_iter(match="message:*")))
        active_sessions = len(list(redis_client.scan_iter(match="session:*")))
    else:
        total_messages = len(mock_messages)
        active_sessions = len(mock_sessions)
    
    return ProjectMetrics(
        total_messages=total_messages,
        active_sessions=active_sessions,
        response_time=2.5,
        system_status="healthy"
    )

@app.get("/api/admin/sessions")
async def get_active_sessions(user: dict = Depends(get_current_user)):
    """Get all active chat sessions"""
    if redis_available:
        sessions = []
        for key in redis_client.scan_iter(match="session:*"):
            session_data = redis_client.get(key)
            if session_data:
                sessions.append(json.loads(session_data))
        return sessions
    else:
        return mock_sessions

@app.websocket("/ws/admin")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Handle incoming WebSocket messages
            pass
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
