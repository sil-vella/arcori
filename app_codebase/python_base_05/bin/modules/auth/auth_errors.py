"""Auth module error codes (email verification)."""

from __future__ import annotations

from core.errors.contracts.register_module_error_contract import ModuleErrorRegistrar
from core.errors.error_spec import ErrorSpec

INVALID_VERIFICATION_TOKEN = ErrorSpec(
    "auth/invalid_verification_token",
    "Invalid or expired verification token",
    http_status=400,
)
EMAIL_ALREADY_VERIFIED = ErrorSpec(
    "auth/email_already_verified",
    "Email is already verified",
    http_status=400,
)
EMAIL_VERIFY_FORBIDDEN = ErrorSpec(
    "auth/email_verify_forbidden",
    "Guest accounts cannot verify email",
    http_status=403,
)


def register_auth_errors(registrar: ModuleErrorRegistrar) -> None:
    registrar.register_module(
        "auth",
        [INVALID_VERIFICATION_TOKEN, EMAIL_ALREADY_VERIFIED, EMAIL_VERIFY_FORBIDDEN],
    )
