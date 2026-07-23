"""Tests for Redis fixed-window rate limiter and HTTP guard path rules."""

from __future__ import annotations

import json
from typing import Any

import pytest
from redis.exceptions import RedisError
from starlette.requests import Request

from core.errors.app_error import AppError
from core.errors.error_codes import RATE_LIMITED
from core.http.middleware.rate_limit_guard import (
    path_exempt_from_rate_limit,
    path_is_public_auth,
    rate_limit_blocked_response,
)
from core.rate_limit.auth_identity import (
    email_identity_key,
    enforce_auth_identity_rate_limit,
)
from core.rate_limit.rate_limit_config import BUCKET_GLOBAL
from core.rate_limit.redis_rate_limiter import (
    RedisRateLimiter,
    reset_rate_limiter_for_tests,
)


class _FakeRedis:
    """Minimal INCR/EXPIRE store for unit tests."""

    def __init__(self) -> None:
        self._counts: dict[str, int] = {}
        self._ttls: dict[str, int] = {}

    def incr(self, key: str) -> int:
        self._counts[key] = self._counts.get(key, 0) + 1
        return self._counts[key]

    def expire(self, key: str, seconds: int) -> bool:
        self._ttls[key] = seconds
        return True


class _FailingRedis:
    def incr(self, key: str) -> int:
        raise RedisError("down")

    def expire(self, key: str, seconds: int) -> bool:
        raise RedisError("down")


def _make_request(
    *,
    path: str,
    method: str = "GET",
    client_host: str = "203.0.113.10",
    forwarded: str | None = None,
) -> Request:
    headers: list[tuple[bytes, bytes]] = []
    if forwarded is not None:
        headers.append((b"x-forwarded-for", forwarded.encode()))
    scope: dict[str, Any] = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": method,
        "scheme": "http",
        "path": path,
        "raw_path": path.encode(),
        "query_string": b"",
        "headers": headers,
        "client": (client_host, 12345),
        "server": ("test", 80),
    }
    return Request(scope)


@pytest.fixture(autouse=True)
def _reset_limiter():
    reset_rate_limiter_for_tests(None)
    yield
    reset_rate_limiter_for_tests(None)


def test_fixed_window_allows_then_blocks():
    limiter = RedisRateLimiter(client=_FakeRedis())  # type: ignore[arg-type]
    first = limiter.check("t", "ip1", max_requests=2, window_s=60)
    second = limiter.check("t", "ip1", max_requests=2, window_s=60)
    third = limiter.check("t", "ip1", max_requests=2, window_s=60)
    assert first.allowed and first.count == 1
    assert second.allowed and second.count == 2
    assert not third.allowed and third.count == 3
    assert third.retry_after_s > 0


def test_redis_error_fail_open():
    limiter = RedisRateLimiter(client=_FailingRedis())  # type: ignore[arg-type]
    result = limiter.check("t", "ip1", max_requests=1, window_s=60)
    assert result.allowed


def test_path_exempt_and_auth_classification():
    assert path_exempt_from_rate_limit("/health")
    assert path_exempt_from_rate_limit("/service/auth/validate")
    assert path_exempt_from_rate_limit("/service/ops/enter-drain")
    assert not path_exempt_from_rate_limit("/public/auth/login")
    assert not path_exempt_from_rate_limit("/authuser/user/profile")
    assert path_is_public_auth("/public/auth/login")
    assert path_is_public_auth("/public/auth/register")
    assert not path_is_public_auth("/authuser/user/profile")


def test_guard_skips_when_disabled(monkeypatch):
    monkeypatch.setenv("ARCORI_RATE_LIMIT_ENABLED", "false")
    reset_rate_limiter_for_tests(RedisRateLimiter(client=_FakeRedis()))  # type: ignore[arg-type]
    req = _make_request(path="/public/auth/login", method="POST")
    assert rate_limit_blocked_response(req) is None


def test_guard_exempts_health(monkeypatch):
    monkeypatch.setenv("ARCORI_RATE_LIMIT_ENABLED", "true")
    fake = _FakeRedis()
    reset_rate_limiter_for_tests(RedisRateLimiter(client=fake))  # type: ignore[arg-type]
    req = _make_request(path="/health", method="GET")
    assert rate_limit_blocked_response(req) is None
    assert fake._counts == {}


def test_guard_blocks_auth_bucket(monkeypatch):
    monkeypatch.setenv("ARCORI_RATE_LIMIT_ENABLED", "true")
    monkeypatch.setenv("ARCORI_RATE_LIMIT_GLOBAL_MAX", "100")
    monkeypatch.setenv("ARCORI_RATE_LIMIT_AUTH_MAX", "2")
    monkeypatch.setenv("ARCORI_RATE_LIMIT_AUTH_WINDOW_S", "60")
    reset_rate_limiter_for_tests(RedisRateLimiter(client=_FakeRedis()))  # type: ignore[arg-type]

    for _ in range(2):
        req = _make_request(path="/public/auth/login", method="POST")
        assert rate_limit_blocked_response(req) is None

    blocked = rate_limit_blocked_response(
        _make_request(path="/public/auth/login", method="POST")
    )
    assert blocked is not None
    assert blocked.status_code == 429
    body = json.loads(blocked.body.decode())
    assert body["error"]["code"] == "rate_limited"
    assert "Retry-After" in blocked.headers


def test_guard_uses_global_before_auth(monkeypatch):
    monkeypatch.setenv("ARCORI_RATE_LIMIT_ENABLED", "true")
    monkeypatch.setenv("ARCORI_RATE_LIMIT_GLOBAL_MAX", "1")
    monkeypatch.setenv("ARCORI_RATE_LIMIT_AUTH_MAX", "100")
    reset_rate_limiter_for_tests(RedisRateLimiter(client=_FakeRedis()))  # type: ignore[arg-type]

    assert (
        rate_limit_blocked_response(
            _make_request(path="/example/cached", method="GET")
        )
        is None
    )
    blocked = rate_limit_blocked_response(
        _make_request(path="/example/cached", method="GET")
    )
    assert blocked is not None
    assert blocked.status_code == 429


def test_email_identity_key_stable():
    assert email_identity_key("A@B.COM") == email_identity_key("a@b.com")


def test_enforce_auth_identity_raises(monkeypatch):
    monkeypatch.setenv("ARCORI_RATE_LIMIT_ENABLED", "true")
    monkeypatch.setenv("ARCORI_RATE_LIMIT_AUTH_IDENTITY_MAX", "1")
    monkeypatch.setenv("ARCORI_RATE_LIMIT_AUTH_IDENTITY_WINDOW_S", "900")
    reset_rate_limiter_for_tests(RedisRateLimiter(client=_FakeRedis()))  # type: ignore[arg-type]

    enforce_auth_identity_rate_limit("user@example.com")
    with pytest.raises(AppError) as exc:
        enforce_auth_identity_rate_limit("user@example.com")
    assert exc.value.code == RATE_LIMITED.code
    assert exc.value.headers.get("Retry-After")


def test_app_error_retry_after_header():
    err = AppError(RATE_LIMITED, headers={"Retry-After": "42"})
    response = err.to_http_response()
    assert response.status_code == 429
    assert response.headers["Retry-After"] == "42"


def test_forwarded_for_used_as_client_ip(monkeypatch):
    monkeypatch.setenv("ARCORI_RATE_LIMIT_ENABLED", "true")
    monkeypatch.setenv("ARCORI_RATE_LIMIT_GLOBAL_MAX", "1")
    fake = _FakeRedis()
    reset_rate_limiter_for_tests(RedisRateLimiter(client=fake))  # type: ignore[arg-type]

    rate_limit_blocked_response(
        _make_request(
            path="/example/cached",
            method="GET",
            forwarded="198.51.100.1, 10.0.0.1",
        )
    )
    keys = list(fake._counts.keys())
    assert len(keys) == 1
    assert "198.51.100.1" in keys[0]
    assert BUCKET_GLOBAL in keys[0]
