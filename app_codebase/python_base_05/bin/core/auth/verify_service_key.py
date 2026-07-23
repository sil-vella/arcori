"""Shared service key verification for HTTP guards and WS auth handshake."""

from __future__ import annotations

from core.auth.auth_config import service_key
from core.auth.secret_compare import secrets_equal
from core.errors.app_error import AppError
from core.errors.error_codes import FORBIDDEN


def verify_service_key_or_raise(provided: str | None) -> None:
    expected = service_key()
    value = (provided or "").strip()
    if not value or not expected or not secrets_equal(value, expected):
        raise AppError(FORBIDDEN, message="Invalid service key")
