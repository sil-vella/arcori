"""Shared access JWT verification for HTTP guards and WS auth handshake."""

from __future__ import annotations

from jwt.exceptions import ExpiredSignatureError, InvalidTokenError

from core.auth import token_service
from core.auth.contracts.auth_context_contract import AuthContext
from core.errors.app_error import AppError
from core.errors.error_codes import INVALID_TOKEN, TOKEN_EXPIRED, UNAUTHORIZED


def _verify_access_token(token: str) -> AuthContext:
    try:
        return token_service.verify_access(token.strip())
    except ExpiredSignatureError as err:
        raise AppError(TOKEN_EXPIRED) from err
    except InvalidTokenError as err:
        raise AppError(INVALID_TOKEN) from err


def verify_bearer_or_raise(token: str | None) -> AuthContext:
    if not token or not str(token).strip():
        raise AppError(UNAUTHORIZED, message="Bearer token required")
    return _verify_access_token(token)


def verify_access_or_raise(token: str | None) -> AuthContext:
    if not token or not str(token).strip():
        raise AppError(UNAUTHORIZED, message="access_token required")
    return _verify_access_token(token)
