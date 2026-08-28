"""Friend match invite notifications (instant modal + accept/decline reply)."""

from __future__ import annotations

from typing import Any

from core.errors.app_error import AppError
from core.notifications.reply_registry import register_reply_handler
from core.notifications.subtype_registry import register_notification_subtype
from core.notifications.subtype_spec import NotificationSubtypeSpec
from core.notifications.response_types import RESPONSE_TYPE_REPLY
from core.utils.dev_logger import customlog
from models.user_notification import NOTIFICATION_TYPE_INSTANT

from modules.friend_match_invite.friend_match_invite_errors import (
    friend_match_inviteForbidden,
    friend_match_inviteNotFound,
    friend_match_inviteNotPending,
)
from modules.friend_match_invite.friend_match_invite_store import (
    InviteRecord,
    accept_invite,
    cancel_expired_invites,
    decline_invite,
    get_invite,
    pop_invite,
)
from modules.notifications.notification_service import soft_delete_by_msg_ids


FRIEND_MATCH_INVITE_SOURCE = "friend_match_invite"
FRIEND_MATCH_INVITE_CATEGORY = "friend_match"
FRIEND_MATCH_INVITE_SUBTYPE = "invite_v1"

LOGGING_SWITCH = True


def invite_notification_msg_id(invite_id: str) -> str:
    return f"friend_match_invite:{invite_id}"


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


def discard_invite_notification(
    invite_id: str,
    *,
    user_id: str | None = None,
) -> int:
    """Soft-delete the invite instant so it cannot resurface on app start."""
    if not invite_id:
        return 0
    result = soft_delete_by_msg_ids(
        [invite_notification_msg_id(invite_id)],
        user_id=user_id,
    )
    deleted = int(result.get("deleted") or 0)
    if LOGGING_SWITCH and deleted:
        customlog(
            f"friend_match_invite: discarded notification invite_id={invite_id} "
            f"user={user_id or '*'} deleted={deleted}"
        )
    return deleted


def purge_expired_invite_notifications() -> int:
    """Drop memory invites past TTL and soft-delete their notifications."""
    expired = cancel_expired_invites()
    deleted = 0
    for rec in expired:
        deleted += discard_invite_notification(
            rec.invite_id,
            user_id=rec.invited_user_id,
        )
    return deleted


def cancel_invite_and_notification(invite_id: str) -> InviteRecord | None:
    """Service/lobby timeout path: remove invite + soft-delete guest notification."""
    purge_expired_invite_notifications()
    rec = pop_invite(invite_id)
    # Always soft-delete by msg_id — covers Python restart / already-expired cases.
    discard_invite_notification(
        invite_id,
        user_id=rec.invited_user_id if rec is not None else None,
    )
    return rec


def prune_stale_invite_notifications_for_user(
    user_id: str,
    messages: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """
    On inbox fetch, drop friend-match invite instants whose invite is dead.
    Fixes rows left unread after dismiss / backend restart / lobby timeout.
    """
    if not messages:
        return messages

    purge_expired_invite_notifications()
    kept: list[dict[str, Any]] = []
    for message in messages:
        if str(message.get("source") or "") != FRIEND_MATCH_INVITE_SOURCE:
            kept.append(message)
            continue
        data = message.get("data") if isinstance(message.get("data"), dict) else {}
        invite_id = str(data.get("inviteId") or "").strip()
        if not invite_id:
            msg_id = str(message.get("msg_id") or "")
            prefix = "friend_match_invite:"
            if msg_id.startswith(prefix):
                invite_id = msg_id[len(prefix) :]
        rec = get_invite(invite_id) if invite_id else None
        # Only waiting invites may still show the Accept/Decline modal.
        if rec is not None and rec.status == "waiting":
            kept.append(message)
            continue
        discard_invite_notification(invite_id, user_id=user_id)
        if LOGGING_SWITCH:
            customlog(
                f"friend_match_invite: pruned stale inbox invite_id={invite_id or '-'} "
                f"user={user_id}"
            )
    return kept


def _parse_invite_id(message: dict[str, Any]) -> str:
    data = message.get("data") or {}
    if not isinstance(data, dict):
        return ""
    invite_id = str(data.get("inviteId", "")).strip()
    return invite_id


def _reply_handler(*, user_id: str, message: dict[str, Any], option_key: str, **_: Any) -> dict[str, Any]:
    invite_id = _parse_invite_id(message)
    if LOGGING_SWITCH:
        customlog(
            f"friend_match_invite: reply user={user_id} option={option_key} "
            f"invite_id={invite_id or '-'}"
        )
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
        # Dead invite (timeout / restart) — still remove the durable popup row.
        discard_invite_notification(invite_id, user_id=user_id)
        raise AppError(friend_match_inviteNotFound)
    except PermissionError:
        raise AppError(friend_match_inviteForbidden)
    except RuntimeError:
        discard_invite_notification(invite_id, user_id=user_id)
        raise AppError(friend_match_inviteNotPending)

    if LOGGING_SWITCH:
        customlog(
            f"friend_match_invite: reply ok user={user_id} option={option_key} "
            f"invite_id={invite_id}"
        )
    # handle_response soft-deletes when delete_notification is set.
    return {
        "success": True,
        "delete_notification": True,
        "data": {"inviteId": invite_id},
    }


def register_friend_match_invite_notification_handlers() -> None:
    register_reply_handler(FRIEND_MATCH_INVITE_SOURCE, _reply_handler)
