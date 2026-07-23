"""Read-through cache factory and default singleton for feature services."""

from __future__ import annotations

from core.cache.cache_config import redis_read_cache_enabled
from core.cache.contracts.read_cache_contract import ReadCacheContract
from core.cache.noop_read_cache import NoOpReadCache
from core.cache.redis_read_cache import RedisReadCache


def build_read_cache() -> ReadCacheContract:
    if redis_read_cache_enabled():
        return RedisReadCache()
    return NoOpReadCache()


read_cache: ReadCacheContract = build_read_cache()
