"""Environment-driven Redis read-cache settings."""

from __future__ import annotations

import os


def redis_read_cache_enabled() -> bool:
    return os.environ.get("ARCORI_REDIS_READ_CACHE_ENABLED", "false").lower() in (
        "1",
        "true",
        "yes",
    )


def redis_host() -> str:
    return os.environ.get("REDIS_HOST", "127.0.0.1")


def redis_port() -> int:
    return int(os.environ.get("REDIS_PORT", "6379"))


def redis_password() -> str | None:
    value = os.environ.get("REDIS_PASSWORD")
    if value is None or value == "":
        return None
    return value


def redis_key_prefix() -> str:
    return os.environ.get("ARCORI_REDIS_KEY_PREFIX", "Arcori:cache:")


def example_cache_ttl_seconds() -> int:
    return int(os.environ.get("ARCORI_CACHE_EXAMPLE_TTL", "60"))
