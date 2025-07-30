import os
from fastapi.testclient import TestClient

# Ensure the OpenAI API key is set for tests
os.environ.setdefault("OPENAI_API_KEY", "test")

from backend.main import app

client = TestClient(app)


def test_ping():
    response = client.get("/api/ping")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
