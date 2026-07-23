"""Environment-driven refresh-session Redis settings."""

from __future__ import annotations

import os

from core.auth.auth_config import jwt_refresh_expires_seconds


def refresh_session_key_prefix() -> str:
    return os.environ.get(
        "ARCORI_REFRESH_SESSION_KEY_PREFIX",
        "Arcori:rt:",
    )


def refresh_session_ttl_seconds() -> int:
    return jwt_refresh_expires_seconds()
