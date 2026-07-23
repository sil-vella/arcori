"""Disconnect cleanup for room membership and user presence."""

from __future__ import annotations

from core.state.state_registry import room_registry, user_presence


def on_ws_authuser_connected(user_id: str, connection_id: str) -> None:
    user_presence.register_authuser_session(user_id, connection_id)


def on_ws_connection_closed(connection_id: str) -> None:
    room_registry.on_connection_closed(connection_id)
    user_presence.unregister_session(connection_id)


def on_ws_authuser_message(connection_id: str) -> None:
    user_presence.touch_session(connection_id)
