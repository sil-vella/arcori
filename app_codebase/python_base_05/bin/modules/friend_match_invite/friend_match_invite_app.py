"""Friend match invite endpoints (create invite + send instant notification)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.request_context import get_auth_user_id
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.state.session_scope import session_scope
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
from models.user_notification import NOTIFICATION_TYPE_INSTANT
from models.avari_profile import AvariProfile
from models.user import User

from modules.players.players_service import AI_EMAIL_DOMAIN, AI_SEED_MARKER

from sqlalchemy import func, or_, select


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

        if not _is_ai_user(invited_user_id):
            create_for_user(
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

        return res.json_ok({"inviteId": invite_id})
    except AppError as err:
        return err.to_http_response()


def _is_ai_user(user_id: str) -> bool:
    """
    AI detection rules must mirror `modules/players/players_service.sample_ai_players`.
    """
    try:
        invited_uid = str(user_id).strip()
        if not invited_uid:
            return False

        with session_scope() as session:
            # Keep the logic as a single query: AvariProfile.notes marker OR AI email domain.
            stmt = (
                select(User.id)
                .outerjoin(AvariProfile, AvariProfile.user_id == User.id)
                .where(
                    User.id == invited_uid,
                    or_(
                        AvariProfile.notes == AI_SEED_MARKER,
                        func.lower(User.email).like(f"%{AI_EMAIL_DOMAIN}"),
                    ),
                )
            )
            return session.execute(stmt).first() is not None
    except Exception:
        # Service-tier endpoint: never break invite flow due to AI detection.
        return False


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
            raise AppError(friend_match_inviteNotFound)

        return res.json_ok(
            {
                "invitedUserId": rec.invited_user_id,
                "isAi": _is_ai_user(rec.invited_user_id),
            },
        )
    except AppError as err:
        return err.to_http_response()
    except (TypeError, ValueError):
        return AppError(
            friend_match_inviteInvalidRequest,
            message="Invalid request payload",
        ).to_http_response()

