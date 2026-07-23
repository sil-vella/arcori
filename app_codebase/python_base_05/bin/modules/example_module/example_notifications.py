"""Example notification reply handlers and demo message creators."""

from __future__ import annotations

from typing import Any

from core.errors.app_error import AppError
from core.notifications.reply_registry import register_reply_handler
from modules.notifications.notification_errors import (
    HANDLER_NOT_FOUND,
    INVALID_RESPONSE,
)
from modules.notifications.notification_service import create_for_user
from models.user_notification import NOTIFICATION_TYPE_INSTANT

_EXAMPLE_INVITE_MSG_ID = "example_invite_v1"
_EXAMPLE_NAVIGATE_MSG_ID = "example_navigate_v1"


def create_demo_notifications_for_user(user_id: str) -> dict[str, str]:
    """Create one navigate and one reply instant notification for demos."""
    navigate_id = create_for_user(
        user_id,
        source="example_module",
        notification_type=NOTIFICATION_TYPE_INSTANT,
        title="Example navigate",
        body="Choose where to go — client-only navigation buttons.",
        category="demo",
        subtype="example_navigate_demo",
        msg_id=_EXAMPLE_NAVIGATE_MSG_ID,
        data={
            "response": {
                "type": "navigate",
                "buttons": [
                    {"label": "Notifications", "screen": "notifications"},
                    {"label": "Home", "screen": "home"},
                ],
            }
        },
    )
    reply_id = create_for_user(
        user_id,
        source="example_module",
        notification_type=NOTIFICATION_TYPE_INSTANT,
        title="Example invite",
        body="Accept or decline — posts to the example_module reply handler.",
        category="demo",
        subtype="example_reply_demo",
        msg_id=_EXAMPLE_INVITE_MSG_ID,
        data={
            "response": {
                "type": "reply",
                "options": [
                    {"key": "accept", "label": "Accept"},
                    {"key": "decline", "label": "Decline"},
                ],
            }
        },
    )
    return {
        "navigate_message_id": navigate_id,
        "reply_message_id": reply_id,
    }


def _example_reply_handler(
    *,
    user_id: str,
    message: dict[str, Any],
    option_key: str,
    **_: Any,
) -> dict[str, Any]:
    if message.get("subtype") != "example_reply_demo":
        raise AppError(HANDLER_NOT_FOUND)

    if option_key == "accept":
        return {"success": True, "data": {"status": "accepted", "user_id": user_id}}
    if option_key == "decline":
        return {"success": True, "data": {"status": "declined"}}
    raise AppError(INVALID_RESPONSE)


def register_example_notification_handlers() -> None:
    register_reply_handler("example_module", _example_reply_handler)
