import os
from fastapi.testclient import TestClient

# Dummy API-nøkkel slik at import av app ikke feiler
os.environ.setdefault("OPENAI_API_KEY", "test")

from backend.main import app

client = TestClient(app)


def test_ping():
    response = client.get("/api/ping")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
