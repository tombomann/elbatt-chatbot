import pytest
import requests
import json

BASE_URL = "http://localhost:8000"


class TestGLM45Compatibility:
    """Test suite for GLM-4.5 compatibility"""

    def test_health_endpoint(self):
        """Test that health endpoint works"""
        response = requests.get(f"{BASE_URL}/api/health")
        assert response.status_code == 200
        assert "status" in response.json()

    def test_chat_endpoint(self):
        """Test chat endpoint with GLM-4.5 optimized prompts"""
        response = requests.post(
            f"{BASE_URL}/api/chat",
            json={"message": "test"},
            headers={"Content-Type": "application/json"},
        )
        assert response.status_code == 200
        assert "response" in response.json()

    def test_environment_variables(self):
        """Test that GLM-4.5 environment variables are set"""
        response = requests.get(f"{BASE_URL}/check-env")
        assert response.status_code == 200
        data = response.json()
        assert data["openai_key_set"] == True

    def test_glm45_optimized_prompts(self):
        """Test GLM-4.5 optimized prompt handling"""
        test_cases = [
            "Hva er batterikapasiteten på en Tesla Model 3?",
            "Kan du slå opp info om bil med regnr AB12345?",
            "Jeg trenger et Varta batteri til min elbil",
        ]

        for prompt in test_cases:
            response = requests.post(
                f"{BASE_URL}/api/chat",
                json={"message": prompt},
                headers={"Content-Type": "application/json"},
            )
            assert response.status_code == 200
            assert "response" in response.json()
