"""Redis one-shot email verification tokens."""

from __future__ import annotations

import hashlib
import logging
import secrets

from redis import Redis
from redis.exceptions import RedisError

from core.cache.cache_config import redis_host, redis_password, redis_port
from core.email.mail_config import email_verify_key_prefix, email_verify_ttl_seconds

logger = logging.getLogger(__name__)


class EmailVerifyStoreError(Exception):
    """Raised when Redis is unavailable (fail-closed on verify)."""


class EmailVerifyStore:
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

    @staticmethod
    def _hash_token(token: str) -> str:
        return hashlib.sha256(token.encode("utf-8")).hexdigest()

    def _key(self, token_hash: str) -> str:
        return f"{email_verify_key_prefix()}{token_hash}"

    def create_token(self, user_id: str) -> str:
        token = secrets.token_urlsafe(32)
        key = self._key(self._hash_token(token))
        ttl = email_verify_ttl_seconds()
        try:
            self._get_client().set(key, user_id, ex=ttl)
        except RedisError as err:
            logger.warning(
                "email_verify_store_fail reason=create user_id=%s error=%s",
                user_id,
                err,
            )
            raise EmailVerifyStoreError("email verify store unavailable") from err
        return token

    def consume_token(self, token: str) -> str | None:
        """Return user_id and delete key; None if missing. Fail-closed on Redis errors."""
        token = token.strip()
        if not token:
            return None
        key = self._key(self._hash_token(token))
        try:
            client = self._get_client()
            user_id = client.get(key)
            if user_id:
                client.delete(key)
            return str(user_id) if user_id else None
        except RedisError as err:
            logger.warning("email_verify_store_fail reason=consume error=%s", err)
            raise EmailVerifyStoreError("email verify store unavailable") from err


_store: EmailVerifyStore | None = None


def get_email_verify_store() -> EmailVerifyStore:
    global _store
    if _store is None:
        _store = EmailVerifyStore()
    return _store


def reset_email_verify_store_for_tests(store: EmailVerifyStore | None = None) -> None:
    global _store
    _store = store
