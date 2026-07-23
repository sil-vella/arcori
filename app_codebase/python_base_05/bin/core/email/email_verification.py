"""Email verification orchestration (soft gate for full accounts)."""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from core.email.email_verify_store import (
    EmailVerifyStoreError,
    get_email_verify_store,
)
from core.email.mail_config import email_verification_enabled, public_app_url
from core.email.smtp_mailer import send_email
from core.errors.app_error import AppError
from core.state.session_scope import session_scope
from modules.auth import user_repository
from modules.auth.auth_errors import (
    EMAIL_ALREADY_VERIFIED,
    EMAIL_VERIFY_FORBIDDEN,
    INVALID_VERIFICATION_TOKEN,
)

logger = logging.getLogger(__name__)


def maybe_send_email_verification(user_id: str, email: str) -> None:
    """Best-effort: create token and SMTP send when feature enabled."""
    if not email_verification_enabled():
        return
    try:
        token = get_email_verify_store().create_token(user_id)
    except EmailVerifyStoreError:
        return

    verify_url = f"{public_app_url()}/wf-template-verify-email?token={token}"
    body = (
        "Verify your email address for Arcori.\n\n"
        f"Open this link (valid for a limited time):\n{verify_url}\n\n"
        "If you did not create an account, ignore this message.\n"
    )
    try:
        send_email(
            to_address=email,
            subject="Verify your email",
            body_text=body,
        )
        logger.info("email_verification_sent user_id=%s", user_id)
    except Exception:
        # Register/convert already succeeded; send is best-effort.
        return


def verify_email_token(token: str) -> dict[str, str]:
    try:
        user_id = get_email_verify_store().consume_token(token)
    except EmailVerifyStoreError as err:
        raise AppError(INVALID_VERIFICATION_TOKEN) from err
    if not user_id:
        raise AppError(INVALID_VERIFICATION_TOKEN)

    with session_scope() as session:
        user = user_repository.find_by_id(session, user_id)
        if user is None or user.is_guest:
            raise AppError(INVALID_VERIFICATION_TOKEN)
        if user.email_verified_at is None:
            user.email_verified_at = datetime.now(timezone.utc)
            session.flush()

    logger.info("email_verification_ok user_id=%s", user_id)
    return {"user_id": user_id, "email_verified": True}


def resend_email_verification(user_id: str) -> None:
    with session_scope() as session:
        user = user_repository.find_by_id(session, user_id)
        if user is None:
            raise AppError(INVALID_VERIFICATION_TOKEN)
        if user.is_guest:
            raise AppError(EMAIL_VERIFY_FORBIDDEN)
        if user.email_verified_at is not None:
            raise AppError(EMAIL_ALREADY_VERIFIED)
        email = user.email

    if not email_verification_enabled():
        return
    maybe_send_email_verification(user_id, email)
