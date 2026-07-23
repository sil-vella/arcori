"""Redis current-refresh-jti allowlist per user (rotation + revocation)."""

from __future__ import annotations

import logging

from redis import Redis
from redis.exceptions import RedisError

from core.auth.refresh_session_config import (
    refresh_session_key_prefix,
    refresh_session_ttl_seconds,
)
from core.cache.cache_config import redis_host, redis_password, redis_port

logger = logging.getLogger(__name__)


class RefreshSessionStoreError(Exception):
    """Raised when Redis is unavailable (fail-closed paths)."""


class RefreshSessionStore:
    def __init__(self, client: Redis | None = None) -> None:
        self._client = client

    def _get_client(self) -> Redis:
        if self._client is None:
            kwargs: dict[str, object] = {
                "host": redis_host(),
                "port": redis_port(),
                "decode_responses": True,
                "socket_connect_timeout": 2,
                "socket_timeout": 2,
            }
            password = redis_password()
            if password is not None:
                kwargs["password"] = password
            self._client = Redis(**kwargs)
        return self._client

    def _key(self, user_id: str) -> str:
        return f"{refresh_session_key_prefix()}user:{user_id}"

    def get_current_jti(self, user_id: str) -> str | None:
        try:
            value = self._get_client().get(self._key(user_id))
        except RedisError as err:
            logger.warning(
                "refresh_session_store_fail reason=get user_id=%s error=%s",
                user_id,
                err,
            )
            raise RefreshSessionStoreError("refresh session store unavailable") from err
        if value is None or value == "":
            return None
        return str(value)

    def set_current_jti(self, user_id: str, jti: str) -> None:
        ttl = refresh_session_ttl_seconds()
        try:
            self._get_client().set(self._key(user_id), jti, ex=ttl)
        except RedisError as err:
            logger.warning(
                "refresh_session_store_fail reason=set user_id=%s error=%s",
                user_id,
                err,
            )
            raise RefreshSessionStoreError("refresh session store unavailable") from err

    def delete_current_jti(self, user_id: str) -> None:
        try:
            self._get_client().delete(self._key(user_id))
        except RedisError as err:
            logger.warning(
                "refresh_session_store_fail reason=delete user_id=%s error=%s",
                user_id,
                err,
            )
            raise RefreshSessionStoreError("refresh session store unavailable") from err


_store: RefreshSessionStore | None = None


def get_refresh_session_store() -> RefreshSessionStore:
    global _store
    if _store is None:
        _store = RefreshSessionStore()
    return _store


def reset_refresh_session_store_for_tests(
    store: RefreshSessionStore | None = None,
) -> None:
    global _store
    _store = store
