"""In-memory presence store tests."""

from __future__ import annotations

from core.presence.in_memory_presence_store import InMemoryPresenceStore
from core.presence.user_presence_service import UserPresenceService
from core.state.user_connection_registry import UserConnectionRegistry


def test_in_memory_presence_register_and_query() -> None:
    store = InMemoryPresenceStore()
    service = UserPresenceService(
        local_connections=UserConnectionRegistry(),
        store=store,
    )
    service.register_authuser_session("user-1", "conn-a")
    assert service.is_online("user-1") is True
    assert service.session_count("user-1") == 1
    sessions = service.sessions_for_user("user-1")
    assert len(sessions) == 1
    assert sessions[0].session_id == "conn-a"
    assert sessions[0].tier == "authuser"


def test_in_memory_presence_unregister() -> None:
    store = InMemoryPresenceStore()
    local = UserConnectionRegistry()
    service = UserPresenceService(local_connections=local, store=store)
    service.register_authuser_session("user-1", "conn-a")
    service.unregister_session("conn-a")
    assert service.is_online("user-1") is False
    assert local.connection_ids_for_user("user-1") == set()


def test_in_memory_presence_touch_updates_last_seen() -> None:
    store = InMemoryPresenceStore()
    service = UserPresenceService(
        local_connections=UserConnectionRegistry(),
        store=store,
    )
    service.register_authuser_session("user-1", "conn-a")
    before = service.sessions_for_user("user-1")[0].last_seen_at
    service.touch_session("conn-a")
    after = service.sessions_for_user("user-1")[0].last_seen_at
    assert after >= before
