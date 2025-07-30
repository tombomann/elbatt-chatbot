import os
import pytest
from fastapi.testclient import TestClient

# Ensure the OpenAI API key is set for tests
os.environ.setdefault("OPENAI_API_KEY", "test")

from backend.main import app  # juster importsti etter prosjektstruktur


@pytest.fixture(autouse=True)
def mock_openai(monkeypatch):
    async def fake_call(prompt, history=None):
        return "Mock response"

    monkeypatch.setattr("backend.openai_service.call_openai_api", fake_call)


client = TestClient(app)


def test_ping():
    response = client.get("/api/ping")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_chat_missing_message():
    response = client.post("/api/chat", json={})
    assert response.status_code == 422
    assert "detail" in response.json()


def test_chat_valid_message():
    data = {"message": "Hei chatbot"}
    response = client.post("/api/chat", json=data)
    assert response.status_code == 200
    assert "response" in response.json()
