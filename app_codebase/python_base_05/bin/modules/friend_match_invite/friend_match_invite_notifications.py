"""Friend match invite notifications (instant modal + accept/decline reply)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from core.errors.app_error import AppError
from core.notifications.reply_registry import register_reply_handler
from core.notifications.subtype_registry import register_notification_subtype
from core.notifications.subtype_spec import NotificationSubtypeSpec
from core.notifications.response_types import RESPONSE_TYPE_REPLY
from models.user_notification import NOTIFICATION_TYPE_INSTANT

from modules.friend_match_invite.friend_match_invite_errors import (
    friend_match_inviteForbidden,
    friend_match_inviteNotFound,
    friend_match_inviteNotPending,
)
from modules.friend_match_invite.friend_match_invite_store import (
    accept_invite,
    decline_invite,
)


FRIEND_MATCH_INVITE_SOURCE = "friend_match_invite"
FRIEND_MATCH_INVITE_CATEGORY = "friend_match"
FRIEND_MATCH_INVITE_SUBTYPE = "invite_v1"


def register_friend_match_invite_notification_subtypes() -> None:
    register_notification_subtype(
        NotificationSubtypeSpec(
            source=FRIEND_MATCH_INVITE_SOURCE,
            category=FRIEND_MATCH_INVITE_CATEGORY,
            subtype=FRIEND_MATCH_INVITE_SUBTYPE,
            default_delivery=NOTIFICATION_TYPE_INSTANT,
            allowed_response_types=frozenset({RESPONSE_TYPE_REPLY}),
            reply_option_keys=frozenset({"accept", "decline"}),
            modal_priority=70,
        )
    )


def _parse_invite_id(message: dict[str, Any]) -> str:
    data = message.get("data") or {}
    if not isinstance(data, dict):
        return ""
    invite_id = str(data.get("inviteId", "")).strip()
    return invite_id


def _reply_handler(*, user_id: str, message: dict[str, Any], option_key: str, **_: Any) -> dict[str, Any]:
    invite_id = _parse_invite_id(message)
    if not invite_id:
        raise AppError(friend_match_inviteNotFound)

    try:
        if option_key == "accept":
            accept_invite(invite_id=invite_id, user_id=user_id)
        elif option_key == "decline":
            decline_invite(invite_id=invite_id, user_id=user_id)
        else:
            # Should not happen: option keys already validated.
            raise AppError(friend_match_inviteNotPending)
    except KeyError:
        raise AppError(friend_match_inviteNotFound)
    except PermissionError:
        raise AppError(friend_match_inviteForbidden)
    except RuntimeError:
        raise AppError(friend_match_inviteNotPending)

    return {"success": True, "data": {"inviteId": invite_id}}


def register_friend_match_invite_notification_handlers() -> None:
    register_reply_handler(FRIEND_MATCH_INVITE_SOURCE, _reply_handler)

