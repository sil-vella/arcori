"""SMTP mailer (stdlib) for transactional email."""

from __future__ import annotations

import logging
import smtplib
from email.message import EmailMessage

from core.email.mail_config import (
    mail_from,
    mail_from_name,
    mail_smtp_encrypt,
    mail_smtp_host,
    mail_smtp_password,
    mail_smtp_port,
    mail_smtp_user,
)

logger = logging.getLogger(__name__)


def send_email(*, to_address: str, subject: str, body_text: str) -> None:
    """Send email; log and re-raise on failure (callers may catch)."""
    host = mail_smtp_host()
    from_addr = mail_from()
    if not host or not from_addr:
        logger.warning("email_send_fail to=%s error=not_configured", to_address)
        raise RuntimeError("SMTP is not configured")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = f"{mail_from_name()} <{from_addr}>"
    msg["To"] = to_address
    msg.set_content(body_text)

    port = mail_smtp_port()
    encrypt = mail_smtp_encrypt()
    user = mail_smtp_user()
    password = mail_smtp_password()

    try:
        if encrypt == "ssl":
            with smtplib.SMTP_SSL(host, port, timeout=15) as smtp:
                if user:
                    smtp.login(user, password)
                smtp.send_message(msg)
        else:
            with smtplib.SMTP(host, port, timeout=15) as smtp:
                smtp.ehlo()
                if encrypt == "starttls":
                    smtp.starttls()
                    smtp.ehlo()
                if user:
                    smtp.login(user, password)
                smtp.send_message(msg)
    except Exception as err:
        logger.warning(
            "email_send_fail to=%s error=%s",
            to_address,
            type(err).__name__,
        )
        raise
