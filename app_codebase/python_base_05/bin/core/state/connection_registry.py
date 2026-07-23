"""Tier 2 — registered WS connections for outbound broadcast."""

from __future__ import annotations

from collections.abc import Callable

ConnectionSend = Callable[[str], None]


class ConnectionRegistry:
    def __init__(self) -> None:
        self._senders: dict[str, ConnectionSend] = {}

    def clear(self) -> None:
        self._senders.clear()

    def register(self, connection_id: str, send: ConnectionSend) -> None:
        self._senders[connection_id] = send

    def unregister(self, connection_id: str) -> None:
        self._senders.pop(connection_id, None)

    def contains(self, connection_id: str) -> bool:
        return connection_id in self._senders

    def send(self, connection_id: str, frame: str) -> None:
        sender = self._senders.get(connection_id)
        if sender is not None:
            sender(frame)
