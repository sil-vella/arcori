"""HS256 JWT issue and verify (access + refresh tokens)."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import uuid4

import jwt
from jwt.exceptions import ExpiredSignatureError, InvalidTokenError

from core.auth.auth_config import (
    jwt_access_expires_seconds,
    jwt_refresh_expires_seconds,
    jwt_refresh_secret,
    jwt_secret,
)
from core.auth.contracts.auth_context_contract import AuthContext
from core.auth.contracts.token_contract import TokenServiceContract

logger = logging.getLogger(__name__)

_ACCESS_TYP = "access"
_REFRESH_TYP = "refresh"


class JwtTokenService:
    def issue_access(
        self,
        user_id: str,
        extra_claims: dict[str, Any] | None = None,
    ) -> str:
        return self._issue(
            user_id=user_id,
            secret=jwt_secret(),
            token_type=_ACCESS_TYP,
            expires_seconds=jwt_access_expires_seconds(),
            extra_claims=extra_claims,
        )

    def issue_refresh(
        self,
        user_id: str,
        extra_claims: dict[str, Any] | None = None,
    ) -> str:
        return self._issue(
            user_id=user_id,
            secret=jwt_refresh_secret(),
            token_type=_REFRESH_TYP,
            expires_seconds=jwt_refresh_expires_seconds(),
            extra_claims=extra_claims,
        )

    def verify_access(self, token: str) -> AuthContext:
        return self._verify(token, jwt_secret(), _ACCESS_TYP)

    def verify_refresh(self, token: str) -> AuthContext:
        return self._verify(token, jwt_refresh_secret(), _REFRESH_TYP)

    def _issue(
        self,
        *,
        user_id: str,
        secret: str,
        token_type: str,
        expires_seconds: int,
        extra_claims: dict[str, Any] | None,
    ) -> str:
        if not secret:
            raise RuntimeError("JWT secret is not configured")
        now = datetime.now(timezone.utc)
        payload: dict[str, Any] = {
            "sub": user_id,
            "typ": token_type,
            "iat": now,
            "exp": now + timedelta(seconds=expires_seconds),
            "jti": str(uuid4()),
        }
        if extra_claims:
            payload.update(extra_claims)
        return jwt.encode(payload, secret, algorithm="HS256")

    def _verify(self, token: str, secret: str, expected_type: str) -> AuthContext:
        if not secret:
            raise InvalidTokenError("JWT secret is not configured")
        required = ["exp", "sub", "typ"]
        if expected_type == _REFRESH_TYP:
            required.append("jti")
        try:
            claims = jwt.decode(
                token,
                secret,
                algorithms=["HS256"],
                options={"require": required},
            )
        except ExpiredSignatureError as err:
            logger.info("auth_failure reason=token_expired")
            raise err
        except InvalidTokenError as err:
            logger.info("auth_failure reason=invalid_token")
            raise err

        if claims.get("typ") != expected_type:
            logger.info("auth_failure reason=wrong_token_type")
            raise InvalidTokenError("wrong token type")

        if expected_type == _REFRESH_TYP and not claims.get("jti"):
            logger.info("auth_failure reason=invalid_token")
            raise InvalidTokenError("refresh token missing jti")

        user_id = str(claims["sub"])
        return AuthContext(user_id=user_id, claims=dict(claims))


token_service: TokenServiceContract = JwtTokenService()
