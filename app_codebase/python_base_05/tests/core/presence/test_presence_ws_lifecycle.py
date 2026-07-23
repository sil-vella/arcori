"""WS lifecycle presence registration tests."""

from __future__ import annotations

from core.presence.in_memory_presence_store import InMemoryPresenceStore
from core.presence.user_presence_service import UserPresenceService
from core.state.room.room_lifecycle import (
    on_ws_authuser_connected,
    on_ws_authuser_message,
    on_ws_connection_closed,
)
from core.state.user_connection_registry import UserConnectionRegistry


def test_ws_lifecycle_registers_and_clears_presence(monkeypatch) -> None:
    local = UserConnectionRegistry()
    store = InMemoryPresenceStore()
    service = UserPresenceService(local_connections=local, store=store)
    monkeypatch.setattr(
        "core.state.room.room_lifecycle.user_presence",
        service,
    )

    on_ws_authuser_connected("user-1", "conn-a")
    assert service.is_online("user-1") is True
    assert local.connection_ids_for_user("user-1") == {"conn-a"}

    on_ws_authuser_message("conn-a")
    assert service.sessions_for_user("user-1")[0].last_seen_at

    on_ws_connection_closed("conn-a")
    assert service.is_online("user-1") is False
    assert local.connection_ids_for_user("user-1") == set()
