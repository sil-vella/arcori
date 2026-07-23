"""Tests for AppError, verify helpers, and catalog parity."""

from __future__ import annotations

import json

import pytest
from jwt.exceptions import ExpiredSignatureError, InvalidTokenError

from core.auth.verify_access import verify_access_or_raise, verify_bearer_or_raise
from core.errors.app_error import AppError
from core.errors.error_codes import (
    CORE_CODES,
    INVALID_TOKEN,
    TOKEN_EXPIRED,
    UNAUTHORIZED,
)
from core.errors.error_spec import ErrorSpec
from core.errors.module_error_registry import module_error_registrar, reset_module_error_registry


def test_app_error_http_envelope():
    err = AppError(TOKEN_EXPIRED)
    response = err.to_http_response()
    assert response.status_code == 401
    body = json.loads(response.body.decode())
    assert body == {"ok": False, "error": {"code": "token_expired", "message": "Access token expired"}}


def test_app_error_ws_envelope():
    err = AppError(TOKEN_EXPIRED)
    frame = json.loads(err.to_ws_frame())
    assert frame == {"ok": False, "error": {"code": "token_expired", "message": "Access token expired"}}


def test_verify_bearer_missing_raises_unauthorized():
    with pytest.raises(AppError) as exc:
        verify_bearer_or_raise(None)
    assert exc.value.code == UNAUTHORIZED.code


def test_verify_access_maps_jwt_exceptions(monkeypatch):
    def _raise_expired(_token: str):
        raise ExpiredSignatureError("expired")

    def _raise_invalid(_token: str):
        raise InvalidTokenError("bad")

    import core.auth.verify_access as mod

    monkeypatch.setattr(mod.token_service, "verify_access", _raise_expired)
    with pytest.raises(AppError) as exc:
        verify_access_or_raise("tok")
    assert exc.value.code == TOKEN_EXPIRED.code

    monkeypatch.setattr(mod.token_service, "verify_access", _raise_invalid)
    with pytest.raises(AppError) as exc:
        verify_access_or_raise("tok")
    assert exc.value.code == INVALID_TOKEN.code


def test_module_error_registration():
    reset_module_error_registry()

    class _Registrar:
        def register_module(self, module_name: str, specs):
            from core.errors.module_error_registry import _ModuleErrorRegistry

            reg = _ModuleErrorRegistry()
            reg.register_module(module_name, specs)

    reg = _Registrar()
    reg.register_module(
        "catalog",
        [ErrorSpec("catalog/sync_failed", "Sync failed", 502)],
    )
    err = AppError(ErrorSpec("catalog/sync_failed", "Sync failed", 502))
    assert err.code == "catalog/sync_failed"
    assert "/" in err.code
    assert err.code not in CORE_CODES


def test_module_registrar_rejects_core_collision():
    reset_module_error_registry()

    class _Registrar:
        def register_module(self, module_name: str, specs):
            from core.errors.module_error_registry import _ModuleErrorRegistry

            reg = _ModuleErrorRegistry()
            reg.register_module(module_name, specs)

    with pytest.raises(ValueError, match="collides"):
        _Registrar().register_module(
            "catalog",
            [ErrorSpec("unauthorized", "nope", 401)],
        )
