"""Guest-register rate-limit helper (IP-keyed, stricter than general auth)."""

from __future__ import annotations

import logging

from core.errors.app_error import AppError
from core.errors.error_codes import RATE_LIMITED
from core.rate_limit.rate_limit_config import (
    BUCKET_GUEST_REGISTER,
    guest_register_policy,
    rate_limit_enabled,
)
from core.rate_limit.redis_rate_limiter import get_rate_limiter

logger = logging.getLogger(__name__)


def enforce_guest_register_rate_limit(client_ip: str | None) -> None:
    """Raise AppError(RATE_LIMITED) when the guest-register IP bucket is exceeded."""
    if not rate_limit_enabled():
        return
    ip = (client_ip or "unknown").strip() or "unknown"
    policy = guest_register_policy()
    result = get_rate_limiter().check(
        BUCKET_GUEST_REGISTER,
        ip,
        max_requests=policy.max_requests,
        window_s=policy.window_s,
    )
    if result.allowed:
        return

    logger.info(
        "rate_limit_hit bucket=%s client_ip=%s limit=%s window_s=%s retry_after_s=%s",
        BUCKET_GUEST_REGISTER,
        ip,
        result.limit,
        result.window_s,
        result.retry_after_s,
    )
    headers: dict[str, str] = {}
    if result.retry_after_s > 0:
        headers["Retry-After"] = str(result.retry_after_s)
    raise AppError(RATE_LIMITED, headers=headers)
