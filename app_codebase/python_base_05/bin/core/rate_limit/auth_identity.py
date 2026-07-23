"""Auth-identity rate-limit helpers (email-keyed bucket after body parse)."""

from __future__ import annotations

import hashlib
import logging

from core.errors.app_error import AppError
from core.errors.error_codes import RATE_LIMITED
from core.rate_limit.rate_limit_config import (
    BUCKET_AUTH_IDENTITY,
    auth_identity_policy,
    rate_limit_enabled,
)
from core.rate_limit.redis_rate_limiter import get_rate_limiter

logger = logging.getLogger(__name__)


def email_identity_key(email: str) -> str:
    normalized = email.strip().lower()
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:32]


def enforce_auth_identity_rate_limit(email: str) -> None:
    """Raise AppError(RATE_LIMITED) when the email identity bucket is exceeded."""
    if not rate_limit_enabled():
        return
    normalized = email.strip().lower()
    if not normalized:
        return

    policy = auth_identity_policy()
    identity = email_identity_key(normalized)
    result = get_rate_limiter().check(
        BUCKET_AUTH_IDENTITY,
        identity,
        max_requests=policy.max_requests,
        window_s=policy.window_s,
    )
    if result.allowed:
        return

    logger.info(
        "rate_limit_hit bucket=%s email_hash=%s limit=%s window_s=%s retry_after_s=%s",
        BUCKET_AUTH_IDENTITY,
        identity[:12],
        result.limit,
        result.window_s,
        result.retry_after_s,
    )
    headers: dict[str, str] = {}
    if result.retry_after_s > 0:
        headers["Retry-After"] = str(result.retry_after_s)
    raise AppError(RATE_LIMITED, headers=headers)
