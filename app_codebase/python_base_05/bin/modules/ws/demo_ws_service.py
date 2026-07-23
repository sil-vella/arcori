"""Demo WebSocket channel handlers — ping/pong and echo."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from core.ws.contracts.ws_message_contract import WsClientMessage, WsConnectionContext


def handle_system(ctx: WsConnectionContext, msg: WsClientMessage) -> dict[str, Any] | None:
    if msg.msg_type == "ping":
        return {
            "type": "pong",
            "channel": "system",
            "ts": datetime.now(timezone.utc).isoformat(),
        }
    return None


def handle_demo_echo(ctx: WsConnectionContext, msg: WsClientMessage) -> dict[str, Any] | None:
    if msg.msg_type == "event":
        text = str(msg.payload.get("text", ""))
        return {
            "type": "event",
            "channel": "demo/echo",
            "payload": {"echo": text},
        }
    return None
