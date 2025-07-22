from fastapi.testclient import TestClient
from varta_api import app

client = TestClient(app)

def test_healthcheck():
    r = client.get("/api/varta/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"
