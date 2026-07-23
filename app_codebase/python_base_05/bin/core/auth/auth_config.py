"""Environment-driven auth settings and production fail-closed checks."""

from __future__ import annotations

import os

_PLACEHOLDER_MARKERS = (
    "change-me",
    "REPLACE_WITH",
    "REPLACE_WITH_",
)


def wf_env() -> str:
    return os.environ.get("ARCORI_ENV", "local").lower()


def is_production() -> bool:
    return wf_env() == "production"


def dev_login_allowed() -> bool:
    return os.environ.get("ARCORI_ALLOW_DEV_LOGIN", "false").lower() in (
        "1",
        "true",
        "yes",
    )


def jwt_secret() -> str:
    return os.environ.get("JWT_SECRET", "")


def jwt_refresh_secret() -> str:
    return os.environ.get("JWT_REFRESH_SECRET", "")


def jwt_access_expires_seconds() -> int:
    return int(os.environ.get("JWT_ACCESS_EXPIRES_SECONDS", "3600"))


def jwt_refresh_expires_seconds() -> int:
    return int(os.environ.get("JWT_REFRESH_EXPIRES_SECONDS", "604800"))


def service_key() -> str:
    return os.environ.get("SERVICE_KEY", "")


def cors_allowed_origins() -> tuple[str, ...]:
    raw = os.environ.get("CORS_ALLOWED_ORIGINS", "")
    if not raw.strip():
        return ()
    return tuple(part.strip() for part in raw.split(",") if part.strip())


def app_debug_enabled() -> bool:
    return os.environ.get("APP_DEBUG", "0") == "1"


def _looks_like_placeholder(value: str) -> bool:
    lowered = value.lower()
    return any(marker.lower() in lowered for marker in _PLACEHOLDER_MARKERS)


def _require_non_empty(name: str, value: str) -> None:
    if not value or _looks_like_placeholder(value):
        raise RuntimeError(
            f"{name} must be set to a strong secret when ARCORI_ENV=production"
        )


def require_secrets_for_production() -> None:
    """Fail closed at startup when production env lacks real secrets."""
    if not is_production():
        return
    _require_non_empty("JWT_SECRET", jwt_secret())
    _require_non_empty("JWT_REFRESH_SECRET", jwt_refresh_secret())
    _require_non_empty("SERVICE_KEY", service_key())
    if app_debug_enabled():
        raise RuntimeError("APP_DEBUG must not be enabled when ARCORI_ENV=production")


def require_app_debug_safe() -> None:
    if is_production() and app_debug_enabled():
        raise RuntimeError("APP_DEBUG must not be enabled when ARCORI_ENV=production")
