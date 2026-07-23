"""Attach WebSocket routes to the FastAPI app."""

from __future__ import annotations

from fastapi import FastAPI, WebSocket

from core.errors.module_error_registry import reset_module_error_registry
from core.ws.service.channel_registry import reset_channel_registry
from core.ws.ws_dispatcher import run_ws_connection
from modules.module_registry import register_application_channels, register_application_errors


def configure_websockets(app: FastAPI) -> None:
    """Register WS channel modules and mount /ws/* routes on ``app``."""
    reset_module_error_registry()
    register_application_errors()
    reset_channel_registry()
    register_application_channels()

    @app.websocket("/ws/public")
    async def ws_public(websocket: WebSocket) -> None:
        await run_ws_connection(websocket, tier="public")

    @app.websocket("/ws/authuser")
    async def ws_authuser(websocket: WebSocket) -> None:
        await run_ws_connection(websocket, tier="authuser")

    @app.websocket("/ws/service")
    async def ws_service(websocket: WebSocket) -> None:
        await run_ws_connection(websocket, tier="service")
