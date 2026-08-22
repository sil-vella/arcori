"""Friend match invite endpoints (create invite + send instant notification)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.request_context import get_auth_user_id
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.utils.dev_logger import customlog
from modules.auth.auth_service import parse_json_body
from modules.friend_match_invite.friend_match_invite_errors import (
    friend_match_inviteInvalidRequest,
    friend_match_inviteUnauthorized,
    friend_match_inviteNotFound,
)
from modules.friend_match_invite.friend_match_invite_notifications import (
    FRIEND_MATCH_INVITE_CATEGORY,
    FRIEND_MATCH_INVITE_SOURCE,
    FRIEND_MATCH_INVITE_SUBTYPE,
)
from modules.friend_match_invite.friend_match_invite_store import (
    create_invite,
    get_invite,
)
from modules.notifications.notification_service import create_for_user
from modules.players.players_service import is_ai_user
from models.user_notification import NOTIFICATION_TYPE_INSTANT

LOGGING_SWITCH = True


def register_friend_match_invite_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_post(
        "/friend_match_invites/create",
        lambda: _handle_create(res),
    )
    routes.service_post(
        "/friend_match_invites/resolve",
        lambda: _handle_resolve(res),
    )


def _handle_create(res: HttpResponseContract):
    try:
        host_user_id = get_auth_user_id()
        if not host_user_id:
            raise AppError(friend_match_inviteUnauthorized)

        body = parse_json_body()
        invited_user_id = str(body.get("invited_user_id", "")).strip()
        if not invited_user_id:
            raise AppError(
                friend_match_inviteInvalidRequest,
                message="invited_user_id is required",
            )

        invite_id = create_invite(
            host_user_id=str(host_user_id).strip(),
            invited_user_id=invited_user_id,
        )

        invited_is_ai = is_ai_user(invited_user_id)
        if LOGGING_SWITCH:
            customlog(
                f"friend_match_invite: create invite_id={invite_id} "
                f"host={host_user_id} invited={invited_user_id} is_ai={invited_is_ai}"
            )

        if not invited_is_ai:
            message_id = create_for_user(
                invited_user_id,
                source=FRIEND_MATCH_INVITE_SOURCE,
                notification_type=NOTIFICATION_TYPE_INSTANT,
                title="Friend match invite",
                body="Accept to join the invite lobby.",
                category=FRIEND_MATCH_INVITE_CATEGORY,
                subtype=FRIEND_MATCH_INVITE_SUBTYPE,
                msg_id=f"friend_match_invite:{invite_id}",
                data={
                    "inviteId": invite_id,
                    "response": {
                        "type": "reply",
                        "options": [
                            {"key": "accept", "label": "Accept"},
                            {"key": "decline", "label": "Decline"},
                        ]
                    },
                },
            )
            if LOGGING_SWITCH:
                customlog(
                    f"friend_match_invite: notification created invite_id={invite_id} "
                    f"invited={invited_user_id} message_id={message_id}"
                )
        else:
            if LOGGING_SWITCH:
                customlog(
                    f"friend_match_invite: notification skipped (AI) "
                    f"invite_id={invite_id} invited={invited_user_id}"
                )

        return res.json_ok({"inviteId": invite_id})
    except AppError as err:
        return err.to_http_response()


def _handle_resolve(res: HttpResponseContract):
    try:
        body = parse_json_body()
        invite_id = str(body.get("inviteId", "")).strip()
        if not invite_id:
            raise AppError(
                friend_match_inviteInvalidRequest,
                message="inviteId is required",
            )

        rec = get_invite(invite_id)
        if rec is None:
            if LOGGING_SWITCH:
                customlog(f"friend_match_invite: resolve not_found invite_id={invite_id}")
            raise AppError(friend_match_inviteNotFound)

        invited_is_ai = is_ai_user(rec.invited_user_id)
        if LOGGING_SWITCH:
            customlog(
                f"friend_match_invite: resolve invite_id={invite_id} "
                f"invited={rec.invited_user_id} is_ai={invited_is_ai}"
            )

        return res.json_ok(
            {
                "invitedUserId": rec.invited_user_id,
                "isAi": invited_is_ai,
            },
        )
    except AppError as err:
        return err.to_http_response()
    except (TypeError, ValueError):
        return AppError(
            friend_match_inviteInvalidRequest,
            message="Invalid request payload",
        ).to_http_response()
