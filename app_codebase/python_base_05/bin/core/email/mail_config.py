"""Environment-driven SMTP and email-verification settings."""

from __future__ import annotations

import os


def email_verification_enabled() -> bool:
    return os.environ.get("ARCORI_EMAIL_VERIFICATION_ENABLED", "false").lower() in (
        "1",
        "true",
        "yes",
    )


def mail_smtp_host() -> str:
    return os.environ.get("MAIL_SMTP_HOST", "").strip()


def mail_smtp_port() -> int:
    return int(os.environ.get("MAIL_SMTP_PORT", "465"))


def mail_smtp_encrypt() -> str:
    return os.environ.get("MAIL_SMTP_ENCRYPT", "ssl").strip().lower() or "ssl"


def mail_smtp_user() -> str:
    return os.environ.get("MAIL_SMTP_USER", "").strip()


def mail_smtp_password() -> str:
    return os.environ.get("MAIL_SMTP_PASSWORD", "")


def mail_from() -> str:
    return os.environ.get("MAIL_FROM", "").strip()


def mail_from_name() -> str:
    return os.environ.get("MAIL_FROM_NAME", "").strip() or "Arcori"


def email_verify_ttl_seconds() -> int:
    return int(os.environ.get("ARCORI_EMAIL_VERIFY_TTL_SECONDS", "86400"))


def email_verify_key_prefix() -> str:
    return os.environ.get(
        "ARCORI_EMAIL_VERIFY_KEY_PREFIX",
        "Arcori:email_verify:",
    )


def public_app_url() -> str:
    return os.environ.get("ARCORI_PUBLIC_APP_URL", "http://127.0.0.1:3002").rstrip(
        "/"
    )
