import pytest
import os
from fastapi.testclient import TestClient

# Bruk dummy API-nøkkel slik at openai_service ikke feiler under import
os.environ.setdefault("OPENAI_API_KEY", "test")

from backend.main import app  # juster importsti etter prosjektstruktur

client = TestClient(app)


def test_ping():
    response = client.get("/api/ping")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_chat_missing_message():
    response = client.post("/api/chat", json={})
    assert response.status_code == 422
    assert "detail" in response.json()


def test_chat_valid_message(monkeypatch):
    async def fake_call_openai_api(msg):
        return "Hei fra test"

    # Patch funksjonen som kaller OpenAI slik at testen ikke gjør nettverkskall
    monkeypatch.setattr("backend.main.call_openai_api", fake_call_openai_api)

    data = {"message": "Hei chatbot"}
    response = client.post("/api/chat", json=data)
    assert response.status_code == 200
    assert response.json() == {"response": "Hei fra test"}
