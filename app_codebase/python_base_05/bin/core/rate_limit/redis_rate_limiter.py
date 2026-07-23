"""Redis fixed-window rate limiter shared across Gunicorn workers."""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass

from redis import Redis
from redis.exceptions import RedisError

from core.cache.cache_config import redis_host, redis_password, redis_port
from core.rate_limit.rate_limit_config import rate_limit_key_prefix

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class RateLimitResult:
    allowed: bool
    count: int
    limit: int
    window_s: int
    retry_after_s: int


class RedisRateLimiter:
    def __init__(self, client: Redis | None = None) -> None:
        self._client = client
        self._owns_client = client is None

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

    def check(
        self,
        bucket: str,
        identifier: str,
        *,
        max_requests: int,
        window_s: int,
    ) -> RateLimitResult:
        """Increment fixed-window counter; fail-open on Redis errors."""
        if max_requests <= 0 or window_s <= 0:
            return RateLimitResult(
                allowed=True,
                count=0,
                limit=max_requests,
                window_s=window_s,
                retry_after_s=0,
            )

        now = int(time.time())
        window_id = now // window_s
        key = f"{rate_limit_key_prefix()}{bucket}:{window_id}:{identifier}"
        ttl = window_s - (now % window_s)
        if ttl <= 0:
            ttl = window_s

        try:
            client = self._get_client()
            count = int(client.incr(key))
            if count == 1:
                client.expire(key, window_s)
            allowed = count <= max_requests
            retry_after = 0 if allowed else ttl
            return RateLimitResult(
                allowed=allowed,
                count=count,
                limit=max_requests,
                window_s=window_s,
                retry_after_s=retry_after,
            )
        except RedisError as err:
            logger.warning(
                "rate_limit_store_fail_open bucket=%s error=%s",
                bucket,
                err,
            )
            return RateLimitResult(
                allowed=True,
                count=0,
                limit=max_requests,
                window_s=window_s,
                retry_after_s=0,
            )


_limiter: RedisRateLimiter | None = None


def get_rate_limiter() -> RedisRateLimiter:
    global _limiter
    if _limiter is None:
        _limiter = RedisRateLimiter()
    return _limiter


def reset_rate_limiter_for_tests(limiter: RedisRateLimiter | None = None) -> None:
    """Test helper: replace or clear the process-wide limiter singleton."""
    global _limiter
    _limiter = limiter
