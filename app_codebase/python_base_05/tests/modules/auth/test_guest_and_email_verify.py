"""Guest register domain + bucket tests; email verification store/flow."""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest

from core.auth.contracts.auth_context_contract import AuthContext
from core.email.email_verification import verify_email_token
from core.email.email_verify_store import (
    EmailVerifyStore,
    reset_email_verify_store_for_tests,
)
from core.errors.app_error import AppError
from core.rate_limit.redis_rate_limiter import (
    RedisRateLimiter,
    reset_rate_limiter_for_tests,
)
from modules.auth.auth_errors import INVALID_VERIFICATION_TOKEN
from modules.auth.auth_service import AuthServiceError, register


class _FakeRedis:
    def __init__(self) -> None:
        self._data: dict[str, str] = {}

    def get(self, key: str) -> str | None:
        return self._data.get(key)

    def set(self, key: str, value: str, ex: int | None = None) -> bool:
        self._data[key] = value
        return True

    def delete(self, key: str) -> int:
        if key in self._data:
            del self._data[key]
            return 1
        return 0

    def incr(self, key: str) -> int:
        self._data[key] = str(int(self._data.get(key, "0")) + 1)
        return int(self._data[key])

    def expire(self, key: str, seconds: int) -> bool:
        return True


@pytest.fixture(autouse=True)
def _reset_stores():
    reset_rate_limiter_for_tests(None)
    reset_email_verify_store_for_tests(None)
    yield
    reset_rate_limiter_for_tests(None)
    reset_email_verify_store_for_tests(None)


def test_guest_register_rejects_non_guest_domain():
    with pytest.raises(AuthServiceError) as exc:
        register(
            username="guestabc",
            email="someone@example.com",
            password="secret123",
            is_guest=True,
        )
    assert exc.value.code == "invalid_request"


def test_full_register_rejects_guest_domain():
    with pytest.raises(AuthServiceError) as exc:
        register(
            username="realuser",
            email="guestx@arcori.arcori",
            password="secret123",
            is_guest=False,
        )
    assert exc.value.code == "invalid_request"


@patch("modules.auth.auth_service.maybe_send_email_verification")
@patch("modules.auth.auth_service.enforce_auth_identity_rate_limit")
@patch("modules.auth.auth_service.enforce_guest_register_rate_limit")
@patch("modules.auth.auth_service.get_refresh_session_store")
@patch("modules.auth.auth_service.session_scope")
@patch("modules.auth.auth_service.user_repository")
def test_guest_register_enforces_guest_bucket(
    repo, scope, get_store, guest_rl, identity_rl, send_mail
):
    session = MagicMock()
    scope.return_value.__enter__.return_value = session
    repo.find_by_email.return_value = None
    repo.find_by_username.return_value = None
    user = MagicMock()
    user.id = uuid4()
    user.is_guest = True
    repo.create_user.return_value = user
    get_store.return_value = MagicMock()

    with patch("modules.auth.auth_service.token_service") as ts:
        ts.issue_access.return_value = "a"
        ts.issue_refresh.return_value = "r"
        ts.verify_refresh.return_value = AuthContext(
            user_id=str(user.id),
            claims={"jti": "j1", "typ": "refresh", "sub": str(user.id)},
        )
        register(
            username="guestabc1",
            email="guestabc1@arcori.arcori",
            password="guestabc1123456",
            is_guest=True,
        )

    guest_rl.assert_called_once()
    send_mail.assert_not_called()


def test_email_verify_token_roundtrip(monkeypatch):
    monkeypatch.setenv("ARCORI_EMAIL_VERIFICATION_ENABLED", "true")
    store = EmailVerifyStore(client=_FakeRedis())  # type: ignore[arg-type]
    reset_email_verify_store_for_tests(store)
    user_id = str(uuid4())
    token = store.create_token(user_id)

    user = MagicMock()
    user.is_guest = False
    user.email_verified_at = None

    with (
        patch("core.email.email_verification.session_scope") as scope,
        patch("core.email.email_verification.user_repository") as repo,
    ):
        scope.return_value.__enter__.return_value = MagicMock()
        repo.find_by_id.return_value = user
        result = verify_email_token(token)

    assert result["email_verified"] is True
    assert user.email_verified_at is not None
    assert isinstance(user.email_verified_at, datetime)


def test_email_verify_invalid_token():
    store = EmailVerifyStore(client=_FakeRedis())  # type: ignore[arg-type]
    reset_email_verify_store_for_tests(store)
    with pytest.raises(AppError) as exc:
        verify_email_token("nope")
    assert exc.value.code == INVALID_VERIFICATION_TOKEN.code


def test_guest_register_bucket_trips(monkeypatch):
    monkeypatch.setenv("ARCORI_RATE_LIMIT_ENABLED", "true")
    monkeypatch.setenv("ARCORI_RATE_LIMIT_GUEST_REGISTER_MAX", "2")
    monkeypatch.setenv("ARCORI_RATE_LIMIT_GUEST_REGISTER_WINDOW_S", "3600")
    reset_rate_limiter_for_tests(RedisRateLimiter(client=_FakeRedis()))  # type: ignore[arg-type]

    from core.rate_limit.guest_register import enforce_guest_register_rate_limit

    enforce_guest_register_rate_limit("1.2.3.4")
    enforce_guest_register_rate_limit("1.2.3.4")
    with pytest.raises(AppError) as exc:
        enforce_guest_register_rate_limit("1.2.3.4")
    assert exc.value.code == "rate_limited"
