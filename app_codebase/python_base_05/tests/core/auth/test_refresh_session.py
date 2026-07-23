"""Tests for refresh-session store and rotated refresh flow."""

from __future__ import annotations

from typing import Any

from unittest.mock import MagicMock, patch

import pytest
from redis.exceptions import RedisError

from core.auth.contracts.auth_context_contract import AuthContext
from core.auth.refresh_session_store import (
    RefreshSessionStore,
    RefreshSessionStoreError,
    reset_refresh_session_store_for_tests,
)
from modules.auth.auth_service import (
    logout_refresh_token,
    refresh_access_token,
)


class _FakeRedis:
    def __init__(self) -> None:
        self._data: dict[str, str] = {}

    def get(self, key: str) -> str | None:
        return self._data.get(key)

    def set(self, key: str, value: str, ex: int | None = None) -> bool:
        self._data[key] = value
        return True

    def delete(self, key: str) -> int:
        if key in self._data:
            del self._data[key]
            return 1
        return 0


class _FailingRedis:
    def get(self, key: str) -> str | None:
        raise RedisError("down")

    def set(self, key: str, value: str, ex: int | None = None) -> bool:
        raise RedisError("down")

    def delete(self, key: str) -> int:
        raise RedisError("down")


@pytest.fixture(autouse=True)
def _reset_store():
    reset_refresh_session_store_for_tests(None)
    yield
    reset_refresh_session_store_for_tests(None)


def test_store_set_get_delete():
    store = RefreshSessionStore(client=_FakeRedis())  # type: ignore[arg-type]
    store.set_current_jti("u1", "jti-a")
    assert store.get_current_jti("u1") == "jti-a"
    store.delete_current_jti("u1")
    assert store.get_current_jti("u1") is None


def test_store_get_fail_closed():
    store = RefreshSessionStore(client=_FailingRedis())  # type: ignore[arg-type]
    with pytest.raises(RefreshSessionStoreError):
        store.get_current_jti("u1")


def _ctx(user_id: str, jti: str) -> AuthContext:
    return AuthContext(
        user_id=user_id,
        claims={"sub": user_id, "typ": "refresh", "jti": jti},
    )


def test_refresh_rotates_and_returns_new_refresh():
    store = RefreshSessionStore(client=_FakeRedis())  # type: ignore[arg-type]
    store.set_current_jti("user-1", "jti-old")
    reset_refresh_session_store_for_tests(store)

    user = MagicMock()
    user.is_guest = False

    with (
        patch("modules.auth.auth_service.token_service") as ts,
        patch("modules.auth.auth_service.session_scope") as scope,
        patch("modules.auth.auth_service.user_repository") as repo,
    ):
        scope.return_value.__enter__.return_value = MagicMock()
        repo.find_by_id.return_value = user
        ts.verify_refresh.side_effect = [
            _ctx("user-1", "jti-old"),
            _ctx("user-1", "jti-new"),
        ]
        ts.issue_access.return_value = "access-new"
        ts.issue_refresh.return_value = "refresh-new"

        payload = refresh_access_token("old-refresh-jwt")

    assert payload is not None
    assert payload["access_token"] == "access-new"
    assert payload["refresh_token"] == "refresh-new"
    assert store.get_current_jti("user-1") == "jti-new"


def test_refresh_reuse_clears_session():
    store = RefreshSessionStore(client=_FakeRedis())  # type: ignore[arg-type]
    store.set_current_jti("user-1", "jti-current")
    reset_refresh_session_store_for_tests(store)

    with patch("modules.auth.auth_service.token_service") as ts:
        ts.verify_refresh.return_value = _ctx("user-1", "jti-stolen")
        payload = refresh_access_token("stolen-refresh-jwt")

    assert payload is None
    assert store.get_current_jti("user-1") is None


def test_logout_revokes_session():
    store = RefreshSessionStore(client=_FakeRedis())  # type: ignore[arg-type]
    store.set_current_jti("user-1", "jti-1")
    reset_refresh_session_store_for_tests(store)

    with patch("modules.auth.auth_service.token_service") as ts:
        ts.verify_refresh.return_value = _ctx("user-1", "jti-1")
        assert logout_refresh_token("refresh-jwt") is True

    assert store.get_current_jti("user-1") is None
    with patch("modules.auth.auth_service.token_service") as ts:
        ts.verify_refresh.return_value = _ctx("user-1", "jti-1")
        assert refresh_access_token("refresh-jwt") is None
