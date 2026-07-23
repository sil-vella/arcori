"""Redis presence integration tests (skip when Redis unavailable)."""

from __future__ import annotations

import os
import uuid

import pytest

redis = pytest.importorskip("redis")

from core.presence.presence_config import presence_key_prefix
from core.presence.redis_presence_store import RedisPresenceStore


def _redis_available() -> bool:
    try:
        client = redis.Redis(
            host=os.environ.get("REDIS_HOST", "127.0.0.1"),
            port=int(os.environ.get("REDIS_PORT", "6379")),
            socket_connect_timeout=1,
            socket_timeout=1,
        )
        client.ping()
        return True
    except Exception:
        return False


pytestmark = pytest.mark.skipif(not _redis_available(), reason="Redis not available")


@pytest.fixture
def store() -> RedisPresenceStore:
    instance = RedisPresenceStore()
    yield instance
    instance.clear()


def test_redis_presence_register_and_query(store: RedisPresenceStore) -> None:
    user_id = str(uuid.uuid4())
    session_id = f"conn-{uuid.uuid4()}"
    store.register_session(
        session_id=session_id,
        user_id=user_id,
        worker_id="test-worker",
        tier="authuser",
        connected_at="2026-07-04T12:00:00+00:00",
        last_seen_at="2026-07-04T12:00:00+00:00",
    )
    sessions = store.sessions_for_user(user_id)
    assert len(sessions) == 1
    assert sessions[0].session_id == session_id

    store.unregister_session(session_id)
    assert store.sessions_for_user(user_id) == []


def test_redis_presence_touch(store: RedisPresenceStore) -> None:
    user_id = str(uuid.uuid4())
    session_id = f"conn-{uuid.uuid4()}"
    store.register_session(
        session_id=session_id,
        user_id=user_id,
        worker_id="test-worker",
        tier="authuser",
        connected_at="2026-07-04T12:00:00+00:00",
        last_seen_at="2026-07-04T12:00:00+00:00",
    )
    store.touch_session(session_id, last_seen_at="2026-07-04T12:05:00+00:00")
    sessions = store.sessions_for_user(user_id)
    assert sessions[0].last_seen_at == "2026-07-04T12:05:00+00:00"
    assert presence_key_prefix() in store._session_key(session_id)
