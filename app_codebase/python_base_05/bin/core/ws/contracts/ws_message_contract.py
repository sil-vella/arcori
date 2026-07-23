"""WebSocket message shapes — shared wire format matching HTTP JSON envelope."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class WsConnectionContext:
    """Per-connection state after tier auth (if required)."""

    tier: str
    connection_id: str
    user_id: str | None = None
    claims: dict[str, Any] = field(default_factory=dict)
    authenticated: bool = False


@dataclass
class WsClientMessage:
    """Parsed client frame body (the ``data`` object when ok)."""

    msg_type: str
    channel: str
    payload: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_data(cls, data: dict[str, Any]) -> WsClientMessage | None:
        msg_type = str(data.get("type", "")).strip()
        channel = str(data.get("channel", "")).strip()
        if not msg_type or not channel:
            return None
        payload = data.get("payload")
        if not isinstance(payload, dict):
            payload = {}
        return cls(msg_type=msg_type, channel=channel, payload=payload)
