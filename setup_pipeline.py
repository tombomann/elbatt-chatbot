import os

os.makedirs(".github/workflows", exist_ok=True)
os.makedirs("tests", exist_ok=True)

with open("tests/test_main.py", "w") as f:
    f.write(
        """\
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_ping():
    response = client.get("/api/ping")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
"""
    )

with open(".github/workflows/full-pipeline.yml", "w") as f:
    f.write(
        """\
name: Full CI/CD with Tests and SonarCloud

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-test-analyze-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
          pip install pytest

      - name: Run Pytest
        run: pytest tests/

      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@v2
        with:
          projectBaseDir: .
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

      - name: Deploy to Hetzner
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SCALEAWAY_HOST }}
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /root/elbatt-chatbot
            git pull origin main
            systemctl restart elbatt-chatbot
"""
    )
