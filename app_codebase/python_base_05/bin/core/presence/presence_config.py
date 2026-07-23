"""Environment-driven user presence settings."""

from __future__ import annotations

import os
import socket


def presence_enabled() -> bool:
    return os.environ.get("ARCORI_PRESENCE_ENABLED", "false").lower() in (
        "1",
        "true",
        "yes",
    )


def presence_session_ttl_seconds() -> int:
    return int(os.environ.get("ARCORI_PRESENCE_SESSION_TTL_SECONDS", "90"))


def presence_key_prefix() -> str:
    return os.environ.get("ARCORI_PRESENCE_KEY_PREFIX", "Arcori:presence:")


def worker_id() -> str:
    explicit = os.environ.get("ARCORI_WORKER_ID", "").strip()
    if explicit:
        return explicit
    return f"{socket.gethostname()}:{os.getpid()}"
