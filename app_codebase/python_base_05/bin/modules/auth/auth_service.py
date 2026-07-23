"""Auth business logic: dev login, refresh, validate, register, login."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

from jwt.exceptions import ExpiredSignatureError, InvalidTokenError

from core.auth import token_service
from core.auth.auth_config import dev_login_allowed
from core.auth.refresh_session_store import (
    RefreshSessionStoreError,
    get_refresh_session_store,
)
from core.email.email_verification import maybe_send_email_verification
from core.http.request_context import get_client_ip, get_current_request, get_user_agent
from core.rate_limit.auth_identity import enforce_auth_identity_rate_limit
from core.rate_limit.guest_register import enforce_guest_register_rate_limit
from core.state.session_scope import session_scope
from core.utils.dev_logger import customlog
from modules.auth import login_event_repository, user_repository
from modules.auth.password_utils import hash_password, verify_password

logger = logging.getLogger(__name__)

LOGGING_SWITCH = True


@dataclass
class AuthServiceError(Exception):
    code: str
    message: str
    status: int = 400

    def __str__(self) -> str:
        return self.message


def dev_login(user_id: str) -> dict[str, Any] | None:
    if not dev_login_allowed():
        return None
    user_id = user_id.strip()
    if not user_id:
        return None
    payload = _issue_token_pair(user_id)
    _record_login_event(user_id)
    return payload


GUEST_EMAIL_SUFFIX = "@arcori.arcori"


def register(
    *,
    username: str,
    email: str,
    password: str,
    is_guest: bool = False,
) -> dict[str, Any]:
    username = username.strip()
    email = email.strip().lower()
    password = password.strip()

    if not username or not email or not password:
        raise AuthServiceError(
            code="invalid_request",
            message="username, email, and password are required",
            status=400,
        )
    if len(username) > 64 or len(email) > 255:
        raise AuthServiceError(
            code="invalid_request",
            message="username or email exceeds maximum length",
            status=400,
        )

    if is_guest:
        if not email.endswith(GUEST_EMAIL_SUFFIX):
            raise AuthServiceError(
                code="invalid_request",
                message="Guest accounts must use the @arcori.arcori email domain",
                status=400,
            )
        enforce_guest_register_rate_limit(get_client_ip())
    elif email.endswith(GUEST_EMAIL_SUFFIX):
        raise AuthServiceError(
            code="invalid_request",
            message="Choose a personal email address for a full account",
            status=400,
        )

    enforce_auth_identity_rate_limit(email)

    if LOGGING_SWITCH and is_guest:
        customlog(f"auth_service.register: guest account username={username} email={email}")

    with session_scope() as session:
        if user_repository.find_by_email(session, email) is not None:
            if LOGGING_SWITCH and is_guest:
                customlog(f"auth_service.register: guest email already taken email={email}")
            raise AuthServiceError(
                code="email_taken",
                message="Email is already registered",
                status=409,
            )
        if user_repository.find_by_username(session, username) is not None:
            if LOGGING_SWITCH and is_guest:
                customlog(
                    f"auth_service.register: guest username already taken username={username}"
                )
            raise AuthServiceError(
                code="username_taken",
                message="Username is already taken",
                status=409,
            )
        user = user_repository.create_user(
            session,
            username=username,
            email=email,
            password_hash=hash_password(password),
            is_guest=is_guest,
        )
        user_id = str(user.id)
        is_guest_flag = user.is_guest

    payload = _issue_token_pair(user_id)
    payload["is_guest"] = is_guest_flag
    payload["email_verified"] = False
    if LOGGING_SWITCH and is_guest:
        customlog(f"auth_service.register: guest account created user_id={user_id}")
    _record_login_event(user_id)
    if not is_guest_flag:
        maybe_send_email_verification(user_id, email)
    return payload


def login(*, email: str, password: str) -> dict[str, Any]:
    email = email.strip().lower()
    password = password.strip()

    if not email or not password:
        raise AuthServiceError(
            code="invalid_request",
            message="email and password are required",
            status=400,
        )

    enforce_auth_identity_rate_limit(email)

    is_guest_email = email.endswith("@arcori.arcori")
    if LOGGING_SWITCH and is_guest_email:
        customlog(f"auth_service.login: guest login attempt email={email}")

    with session_scope() as session:
        user = user_repository.find_by_email(session, email)
        if user is None:
            if LOGGING_SWITCH and is_guest_email:
                customlog(f"auth_service.login: guest login failed email={email}")
            raise AuthServiceError(
                code="invalid_credentials",
                message="Invalid email or password",
                status=401,
            )
        password_hash = user.password_hash
        user_id = str(user.id)
        is_guest_flag = user.is_guest
        email_verified = user.email_verified_at is not None

    if not verify_password(password, password_hash):
        if LOGGING_SWITCH and is_guest_email:
            customlog(f"auth_service.login: guest login failed email={email}")
        raise AuthServiceError(
            code="invalid_credentials",
            message="Invalid email or password",
            status=401,
        )

    payload = _issue_token_pair(user_id)
    payload["is_guest"] = is_guest_flag
    payload["email_verified"] = email_verified
    if LOGGING_SWITCH and is_guest_email:
        customlog(
            f"auth_service.login: guest login ok user_id={user_id} "
            f"is_guest={is_guest_flag}"
        )
    _record_login_event(user_id)
    return payload


def refresh_access_token(refresh_token: str) -> dict[str, Any] | None:
    refresh_token = refresh_token.strip()
    if not refresh_token:
        return None
    try:
        ctx = token_service.verify_refresh(refresh_token)
    except (ExpiredSignatureError, InvalidTokenError):
        return None

    presented_jti = str(ctx.claims.get("jti") or "")
    if not presented_jti:
        return None

    store = get_refresh_session_store()
    try:
        current_jti = store.get_current_jti(ctx.user_id)
    except RefreshSessionStoreError:
        return None

    if current_jti is None or current_jti != presented_jti:
        logger.info("refresh_reuse_detected user_id=%s", ctx.user_id)
        try:
            store.delete_current_jti(ctx.user_id)
            logger.info("refresh_revoked user_id=%s reason=reuse", ctx.user_id)
        except RefreshSessionStoreError:
            pass
        return None

    with session_scope() as session:
        user = user_repository.find_by_id(session, ctx.user_id)
        if user is None:
            return None
        is_guest = user.is_guest
        email_verified = user.email_verified_at is not None

    access_token = token_service.issue_access(ctx.user_id)
    new_refresh = token_service.issue_refresh(ctx.user_id)
    try:
        new_ctx = token_service.verify_refresh(new_refresh)
        new_jti = str(new_ctx.claims.get("jti") or "")
        if not new_jti:
            return None
        store.set_current_jti(ctx.user_id, new_jti)
    except (ExpiredSignatureError, InvalidTokenError, RefreshSessionStoreError):
        return None

    logger.info("refresh_rotated user_id=%s", ctx.user_id)
    return {
        "user_id": ctx.user_id,
        "access_token": access_token,
        "refresh_token": new_refresh,
        "token_type": "Bearer",
        "is_guest": is_guest,
        "email_verified": email_verified,
    }


def logout_refresh_token(refresh_token: str) -> bool:
    """Revoke the refresh session for the token's user. Idempotent."""
    refresh_token = refresh_token.strip()
    if not refresh_token:
        return False
    try:
        ctx = token_service.verify_refresh(refresh_token)
    except (ExpiredSignatureError, InvalidTokenError):
        return False

    store = get_refresh_session_store()
    try:
        store.delete_current_jti(ctx.user_id)
    except RefreshSessionStoreError:
        return False
    logger.info("refresh_revoked user_id=%s reason=logout", ctx.user_id)
    return True


def revoke_refresh_session(user_id: str, *, reason: str) -> None:
    """Best-effort revoke by user id (delete/convert)."""
    store = get_refresh_session_store()
    try:
        store.delete_current_jti(user_id)
        logger.info("refresh_revoked user_id=%s reason=%s", user_id, reason)
    except RefreshSessionStoreError:
        logger.warning(
            "refresh_session_store_fail reason=revoke_user user_id=%s",
            user_id,
        )


def validate_access_token(access_token: str) -> dict[str, Any] | None:
    access_token = access_token.strip()
    if not access_token:
        return None
    try:
        ctx = token_service.verify_access(access_token)
    except (ExpiredSignatureError, InvalidTokenError):
        return None
    return {
        "user_id": ctx.user_id,
        "claims": ctx.claims,
        "valid": True,
    }


def get_user_profile(user_id: str) -> dict[str, Any] | None:
    with session_scope() as session:
        user = user_repository.find_by_id(session, user_id)
        if user is None:
            return None
        return {
            "user_id": str(user.id),
            "username": user.username,
            "email": user.email,
            "is_guest": user.is_guest,
            "email_verified": user.email_verified_at is not None,
            "account_type": "Guest" if user.is_guest else "Regular",
            "avatar_url": user.avatar_url,
            "created_at": user.created_at.isoformat(),
        }


def delete_account(
    *,
    user_id: str,
    password: str,
    confirmation: str,
) -> None:
    confirmation = confirmation.strip()
    password = password.strip()

    if confirmation != "DELETE":
        raise AuthServiceError(
            code="invalid_request",
            message="Type DELETE to confirm account deletion",
            status=400,
        )
    if not password:
        raise AuthServiceError(
            code="invalid_request",
            message="Password is required",
            status=400,
        )

    with session_scope() as session:
        user = user_repository.find_by_id(session, user_id)
        if user is None:
            raise AuthServiceError(
                code="not_found",
                message="User not found",
                status=404,
            )
        if user.is_guest:
            raise AuthServiceError(
                code="forbidden",
                message="Guest accounts cannot be deleted",
                status=403,
            )
        if not verify_password(password, user.password_hash):
            raise AuthServiceError(
                code="invalid_credentials",
                message="Invalid password",
                status=401,
            )
        avatar_url = user.avatar_url
        user_repository.delete_by_id(session, user_id)

    from modules.user.avatar_service import delete_avatar_file_for_user

    delete_avatar_file_for_user(user_id, avatar_url)
    revoke_refresh_session(user_id, reason="delete")

    if LOGGING_SWITCH:
        customlog(f"auth_service.delete_account: deleted user_id={user_id}")


def convert_guest_account(
    *,
    user_id: str,
    guest_email: str,
    username: str,
    email: str,
    password: str,
) -> dict[str, Any]:
    guest_email = guest_email.strip().lower()
    username = username.strip()
    email = email.strip().lower()
    password = password.strip()

    if not guest_email or not username or not email or not password:
        raise AuthServiceError(
            code="invalid_request",
            message="guest_email, username, email, and password are required",
            status=400,
        )
    if len(username) > 64 or len(email) > 255:
        raise AuthServiceError(
            code="invalid_request",
            message="username or email exceeds maximum length",
            status=400,
        )
    if email.endswith(GUEST_EMAIL_SUFFIX):
        raise AuthServiceError(
            code="invalid_request",
            message="Choose a personal email address for a full account",
            status=400,
        )

    if LOGGING_SWITCH:
        customlog(
            f"auth_service.convert_guest_account: started user_id={user_id} "
            f"guest_email={guest_email} new_email={email} username={username}"
        )

    with session_scope() as session:
        user = user_repository.find_by_id(session, user_id)
        if user is None:
            raise AuthServiceError(
                code="not_found",
                message="User not found",
                status=404,
            )
        if not user.is_guest:
            raise AuthServiceError(
                code="forbidden",
                message="Only guest accounts can be converted",
                status=403,
            )
        if user.email != guest_email:
            raise AuthServiceError(
                code="invalid_request",
                message="Guest email does not match the signed-in account",
                status=400,
            )
        if user_repository.email_taken_by_other(session, email, user_id):
            raise AuthServiceError(
                code="email_taken",
                message="Email is already registered",
                status=409,
            )
        if user_repository.username_taken_by_other(session, username, user_id):
            raise AuthServiceError(
                code="username_taken",
                message="Username is already taken",
                status=409,
            )
        user_repository.upgrade_guest_to_full(
            session,
            user_id,
            username=username,
            email=email,
            password_hash=hash_password(password),
        )

    if LOGGING_SWITCH:
        customlog(
            f"auth_service.convert_guest_account: upgraded user_id={user_id} "
            f"new_email={email} username={username}"
        )

    revoke_refresh_session(user_id, reason="convert")
    payload = _issue_token_pair(user_id)
    payload["is_guest"] = False
    payload["email_verified"] = False
    _record_login_event(user_id)
    maybe_send_email_verification(user_id, email)
    return payload


def _issue_token_pair(user_id: str) -> dict[str, Any]:
    access_token = token_service.issue_access(user_id)
    refresh_token = token_service.issue_refresh(user_id)
    try:
        ctx = token_service.verify_refresh(refresh_token)
        jti = str(ctx.claims.get("jti") or "")
        if not jti:
            raise AuthServiceError(
                code="internal_error",
                message="Failed to issue refresh session",
                status=500,
            )
        get_refresh_session_store().set_current_jti(user_id, jti)
    except (ExpiredSignatureError, InvalidTokenError, RefreshSessionStoreError) as err:
        logger.warning(
            "refresh_session_store_fail reason=issue user_id=%s error=%s",
            user_id,
            type(err).__name__,
        )
        raise AuthServiceError(
            code="internal_error",
            message="Failed to issue refresh session",
            status=500,
        ) from err
    return {
        "user_id": user_id,
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "Bearer",
    }


def parse_json_body() -> dict[str, Any]:
    request = get_current_request()
    if request is None:
        return {}
    data = getattr(request.state, "json_body", {})
    if not isinstance(data, dict):
        return {}
    return data


def _record_login_event(user_id: str) -> None:
    client_ip = get_client_ip()
    user_agent = get_user_agent()
    try:
        with session_scope() as session:
            login_event_repository.record_login_event(
                session,
                user_id=user_id,
                client_ip=client_ip,
                user_agent=user_agent,
            )
    except Exception as exc:
        if LOGGING_SWITCH:
            customlog(
                f"auth_service._record_login_event: failed user_id={user_id} "
                f"error={exc!r}"
            )
