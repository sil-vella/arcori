"""WebSocket integration: auth handshake + ping on FastAPI."""

from __future__ import annotations

import json
import os

import pytest
from starlette.testclient import TestClient

os.environ.setdefault("ARCORI_ENV", "local")
os.environ.setdefault("JWT_SECRET", "dev-local-jwt-secret-change-me")
os.environ.setdefault("JWT_REFRESH_SECRET", "dev-local-jwt-refresh-secret-change-me")
os.environ.setdefault("SERVICE_KEY", "dev-local-service-key-change-me")
os.environ.setdefault("ARCORI_ALLOW_DEV_LOGIN", "true")

from core.http.http_app import createHttpHandler  # noqa: E402


@pytest.fixture
def client() -> TestClient:
    return TestClient(createHttpHandler())


def _dev_login_token(client: TestClient) -> str:
    response = client.post(
        "/public/auth/dev-login",
        json={"user_id": "ws-test-user"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["ok"] is True
    return body["data"]["access_token"]


def test_ws_public_ping_pong(client: TestClient) -> None:
    with client.websocket_connect("/ws/public") as ws:
        connected = json.loads(ws.receive_text())
        assert connected["ok"] is True
        assert connected["data"]["type"] == "connected"

        ws.send_text(json.dumps({"type": "ping", "channel": "system"}))
        pong = json.loads(ws.receive_text())
        assert pong["ok"] is True
        assert pong["data"]["type"] == "pong"


def test_ws_authuser_ping_pong(client: TestClient) -> None:
    token = _dev_login_token(client)
    with client.websocket_connect("/ws/authuser") as ws:
        ws.send_text(
            json.dumps(
                {
                    "type": "auth",
                    "channel": "system",
                    "payload": {"access_token": token},
                }
            )
        )
        connected = json.loads(ws.receive_text())
        assert connected["ok"] is True
        assert connected["data"]["type"] == "connected"

        ws.send_text(json.dumps({"type": "ping", "channel": "system"}))
        pong = json.loads(ws.receive_text())
        assert pong["ok"] is True
        assert pong["data"]["type"] == "pong"


def test_ws_service_ping_pong(client: TestClient) -> None:
    service_key = os.environ["SERVICE_KEY"]
    with client.websocket_connect("/ws/service") as ws:
        ws.send_text(
            json.dumps(
                {
                    "type": "auth",
                    "channel": "system",
                    "payload": {"service_key": service_key},
                }
            )
        )
        connected = json.loads(ws.receive_text())
        assert connected["ok"] is True
        assert connected["data"]["type"] == "connected"

        ws.send_text(json.dumps({"type": "ping", "channel": "system"}))
        pong = json.loads(ws.receive_text())
        assert pong["ok"] is True
        assert pong["data"]["type"] == "pong"
