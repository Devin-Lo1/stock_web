from fastapi.testclient import TestClient

from app.main import app


def test_health_remains_public_when_api_token_is_enabled(monkeypatch):
    monkeypatch.setenv("API_ACCESS_TOKEN", "test-token")
    client = TestClient(app)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_api_requires_token_when_configured(monkeypatch):
    monkeypatch.setenv("API_ACCESS_TOKEN", "test-token")
    client = TestClient(app)

    response = client.get("/api/v1/positions")

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "API_AUTH_REQUIRED"


def test_api_accepts_bearer_token(monkeypatch):
    monkeypatch.setenv("API_ACCESS_TOKEN", "test-token")
    client = TestClient(app)

    response = client.get(
        "/api/v1/positions",
        headers={"Authorization": "Bearer test-token"},
    )

    assert response.status_code == 200


def test_api_accepts_x_api_token(monkeypatch):
    monkeypatch.setenv("API_ACCESS_TOKEN", "test-token")
    client = TestClient(app)

    response = client.get(
        "/api/v1/positions",
        headers={"X-API-Token": "test-token"},
    )

    assert response.status_code == 200
