import pytest
from fastapi.testclient import TestClient
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


def test_chat_valid_message():
    data = {"message": "Hei chatbot"}
    response = client.post("/api/chat", json=data)
    assert response.status_code == 200
    assert "response" in response.json()
