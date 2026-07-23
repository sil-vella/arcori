"""Redis-backed read-through cache shared across Gunicorn workers."""

from __future__ import annotations

import json
import logging
from typing import Callable, TypeVar

from redis import Redis
from redis.exceptions import RedisError

from core.cache.cache_config import (
    redis_host,
    redis_key_prefix,
    redis_password,
    redis_port,
)

logger = logging.getLogger(__name__)

T = TypeVar("T")


class RedisReadCache:
    def __init__(self) -> None:
        self._client: Redis | None = None

    def is_enabled(self) -> bool:
        return True

    def _full_key(self, key: str) -> str:
        return f"{redis_key_prefix()}{key}"

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

    def get_or_load(
        self,
        key: str,
        ttl_seconds: int,
        loader: Callable[[], T],
    ) -> T:
        full_key = self._full_key(key)
        try:
            client = self._get_client()
            cached = client.get(full_key)
            if cached is not None:
                return json.loads(cached)
            value = loader()
            client.setex(full_key, ttl_seconds, json.dumps(value))
            return value
        except (RedisError, json.JSONDecodeError, TypeError) as err:
            logger.warning(
                "redis_read_cache_fail_open key=%s error=%s",
                key,
                err,
            )
            return loader()

    def delete(self, key: str) -> None:
        full_key = self._full_key(key)
        try:
            self._get_client().delete(full_key)
        except RedisError as err:
            logger.warning(
                "redis_read_cache_delete_fail key=%s error=%s",
                key,
                err,
            )
