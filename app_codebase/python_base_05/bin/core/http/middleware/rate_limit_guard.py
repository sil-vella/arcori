"""HTTP rate-limit gate — 429 on exceeded global / auth IP buckets."""

from __future__ import annotations

import logging

from starlette.requests import Request
from starlette.responses import Response

from core.errors.app_error import AppError
from core.errors.error_codes import RATE_LIMITED
from core.rate_limit.rate_limit_config import (
    BUCKET_AUTH,
    BUCKET_GLOBAL,
    auth_policy,
    global_policy,
    rate_limit_enabled,
)
from core.rate_limit.redis_rate_limiter import RateLimitResult, get_rate_limiter

logger = logging.getLogger(__name__)

_HEALTH_EXACT: frozenset[str] = frozenset({"/health"})
_SERVICE_PREFIX = "/service"
_AUTH_PUBLIC_PREFIX = "/public/auth"


def _normalize_path(path: str) -> str:
    return path.rstrip("/") or "/"


def path_exempt_from_rate_limit(path: str) -> bool:
    normalized = _normalize_path(path)
    if normalized in _HEALTH_EXACT:
        return True
    if normalized == _SERVICE_PREFIX or normalized.startswith(_SERVICE_PREFIX + "/"):
        return True
    return False


def path_is_public_auth(path: str) -> bool:
    normalized = _normalize_path(path)
    return normalized == _AUTH_PUBLIC_PREFIX or normalized.startswith(
        _AUTH_PUBLIC_PREFIX + "/"
    )


def client_ip_from_request(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        first = forwarded.split(",")[0].strip()
        if first:
            return first[:45]
    if request.client is not None and request.client.host:
        return request.client.host[:45]
    return "unknown"


def _log_hit(
    *,
    bucket: str,
    client_ip: str,
    path: str,
    method: str,
    result: RateLimitResult,
) -> None:
    logger.info(
        "rate_limit_hit bucket=%s client_ip=%s path=%s method=%s "
        "limit=%s window_s=%s retry_after_s=%s",
        bucket,
        client_ip,
        path,
        method,
        result.limit,
        result.window_s,
        result.retry_after_s,
    )


def _blocked_response(result: RateLimitResult) -> Response:
    headers: dict[str, str] = {}
    if result.retry_after_s > 0:
        headers["Retry-After"] = str(result.retry_after_s)
    return AppError(RATE_LIMITED, headers=headers).to_http_response()


def rate_limit_blocked_response(request: Request) -> Response | None:
    """Return 429 when a bucket is exceeded; else None (or when disabled)."""
    if request.method == "OPTIONS":
        return None
    if not rate_limit_enabled():
        return None

    path = request.url.path
    if path_exempt_from_rate_limit(path):
        return None

    client_ip = client_ip_from_request(request)
    limiter = get_rate_limiter()

    global_pol = global_policy()
    global_result = limiter.check(
        BUCKET_GLOBAL,
        client_ip,
        max_requests=global_pol.max_requests,
        window_s=global_pol.window_s,
    )
    if not global_result.allowed:
        _log_hit(
            bucket=BUCKET_GLOBAL,
            client_ip=client_ip,
            path=path,
            method=request.method,
            result=global_result,
        )
        return _blocked_response(global_result)

    if path_is_public_auth(path):
        auth_pol = auth_policy()
        auth_result = limiter.check(
            BUCKET_AUTH,
            client_ip,
            max_requests=auth_pol.max_requests,
            window_s=auth_pol.window_s,
        )
        if not auth_result.allowed:
            _log_hit(
                bucket=BUCKET_AUTH,
                client_ip=client_ip,
                path=path,
                method=request.method,
                result=auth_result,
            )
            return _blocked_response(auth_result)

    return None
