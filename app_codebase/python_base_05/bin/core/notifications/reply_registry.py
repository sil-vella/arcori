"""Module reply handler registry for notification response dispatch."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from core.errors.app_error import AppError

ReplyHandler = Callable[..., dict[str, Any]]

_handlers: dict[str, ReplyHandler] = {}


def reset_reply_registry() -> None:
    _handlers.clear()


def register_reply_handler(source: str, handler: ReplyHandler) -> None:
    key = source.strip()
    if not key:
        raise ValueError("source is required")
    _handlers[key] = handler


def dispatch_reply(
    *,
    source: str,
    user_id: str,
    message: dict[str, Any],
    option_key: str,
) -> dict[str, Any]:
    from modules.notifications.notification_errors import HANDLER_NOT_FOUND

    handler = _handlers.get(source.strip())
    if handler is None:
        raise AppError(HANDLER_NOT_FOUND)

    from modules.notifications.notification_errors import INVALID_RESPONSE

    result = handler(
        user_id=user_id,
        message=message,
        option_key=option_key.strip().lower(),
    )
    if not isinstance(result, dict):
        raise AppError(INVALID_RESPONSE, message="Handler returned invalid result")
    if not result.get("success"):
        raise AppError(INVALID_RESPONSE, message="Handler declined the response")
    return result
