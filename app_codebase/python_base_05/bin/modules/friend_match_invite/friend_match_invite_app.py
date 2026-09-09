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
    friend_match_inviteRematchNoHumans,
    friend_match_inviteRematchSeriesInvalid,
)
from modules.friend_match_invite.friend_match_invite_notifications import (
    FRIEND_MATCH_INVITE_CATEGORY,
    FRIEND_MATCH_INVITE_SOURCE,
    FRIEND_MATCH_INVITE_SUBTYPE,
    cancel_invite_and_notification,
    invite_notification_msg_id,
    purge_expired_invite_notifications,
)
from modules.friend_match_invite.friend_match_invite_store import (
    create_invite,
    create_rematch_invite,
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
    routes.authuser_post(
        "/friend_match_invites/create_rematch",
        lambda: _handle_create_rematch(res),
    )
    routes.service_post(
        "/friend_match_invites/resolve",
        lambda: _handle_resolve(res),
    )
    routes.service_post(
        "/friend_match_invites/cancel",
        lambda: _handle_cancel(res),
    )


def _notify_invitee(
    *,
    invite_id: str,
    invited_user_id: str,
    kind: str,
    series_id: str | None = None,
    series_index: int | None = None,
) -> None:
    invited_is_ai = is_ai_user(invited_user_id)
    if invited_is_ai:
        if LOGGING_SWITCH:
            customlog(
                f"friend_match_invite: notification skipped (AI) "
                f"invite_id={invite_id} invited={invited_user_id} kind={kind}"
            )
        return

    is_rematch = kind == "rematch"
    title = "Rematch invite" if is_rematch else "Friend match invite"
    body = (
        "Accept to rematch."
        if is_rematch
        else "Accept to join the invite lobby."
    )
    data: dict = {
        "inviteId": invite_id,
        "kind": kind,
        "response": {
            "type": "reply",
            "options": [
                {"key": "accept", "label": "Accept"},
                {"key": "decline", "label": "Decline"},
            ],
        },
    }
    if is_rematch:
        if series_id:
            data["seriesId"] = series_id
        if series_index is not None:
            data["seriesIndex"] = series_index

    message_id = create_for_user(
        invited_user_id,
        source=FRIEND_MATCH_INVITE_SOURCE,
        notification_type=NOTIFICATION_TYPE_INSTANT,
        title=title,
        body=body,
        category=FRIEND_MATCH_INVITE_CATEGORY,
        subtype=FRIEND_MATCH_INVITE_SUBTYPE,
        msg_id=invite_notification_msg_id(invite_id),
        data=data,
    )
    if LOGGING_SWITCH:
        customlog(
            f"friend_match_invite: notification created invite_id={invite_id} "
            f"invited={invited_user_id} message_id={message_id} kind={kind}"
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

        if LOGGING_SWITCH:
            customlog(
                f"friend_match_invite: create invite_id={invite_id} "
                f"host={host_user_id} invited={invited_user_id} "
                f"is_ai={is_ai_user(invited_user_id)}"
            )

        _notify_invitee(
            invite_id=invite_id,
            invited_user_id=invited_user_id,
            kind="friend",
        )

        return res.json_ok({"inviteId": invite_id})
    except AppError as err:
        return err.to_http_response()


def _handle_create_rematch(res: HttpResponseContract):
    try:
        host_user_id = get_auth_user_id()
        if not host_user_id:
            raise AppError(friend_match_inviteUnauthorized)

        body = parse_json_body()
        prior_match_id = str(
            body.get("prior_match_id") or body.get("priorMatchId") or ""
        ).strip()
        series_id = str(body.get("series_id") or body.get("seriesId") or "").strip()
        series_index_raw = body.get("series_index", body.get("seriesIndex"))
        try:
            series_index = int(series_index_raw)
        except (TypeError, ValueError):
            series_index = 0

        raw_ids = body.get("invited_user_ids") or body.get("invitedUserIds") or []
        if not isinstance(raw_ids, list):
            raise AppError(
                friend_match_inviteInvalidRequest,
                message="invited_user_ids must be a list",
            )
        invited_user_ids = [str(x).strip() for x in raw_ids if str(x).strip()]

        # Notify humans only; AI invitees are stored for rematch seat fill / resolve.
        human_ids: list[str] = []
        ai_ids: list[str] = []
        for uid in invited_user_ids:
            if uid == str(host_user_id).strip():
                continue
            if is_ai_user(uid):
                ai_ids.append(uid)
                continue
            human_ids.append(uid)

        store_invitees = human_ids + ai_ids
        if not store_invitees:
            raise AppError(friend_match_inviteRematchNoHumans)
        if not prior_match_id or not series_id or series_index < 2:
            raise AppError(friend_match_inviteRematchSeriesInvalid)

        try:
            invite_id = create_rematch_invite(
                host_user_id=str(host_user_id).strip(),
                invited_user_ids=store_invitees,
                prior_match_id=prior_match_id,
                series_id=series_id,
                series_index=series_index,
            )
        except ValueError as err:
            raise AppError(
                friend_match_inviteRematchSeriesInvalid,
                message=str(err),
            ) from err

        if LOGGING_SWITCH:
            customlog(
                f"friend_match_invite: create_rematch invite_id={invite_id} "
                f"host={host_user_id} humans={human_ids} ai={ai_ids} "
                f"series={series_id} index={series_index} prior={prior_match_id}"
            )

        for uid in human_ids:
            _notify_invitee(
                invite_id=invite_id,
                invited_user_id=uid,
                kind="rematch",
                series_id=series_id,
                series_index=series_index,
            )
        for uid in ai_ids:
            if LOGGING_SWITCH:
                customlog(
                    f"friend_match_invite: rematch notification skipped (AI) "
                    f"invite_id={invite_id} invited={uid}"
                )

        return res.json_ok(
            {
                "inviteId": invite_id,
                "kind": "rematch",
                "seriesId": series_id,
                "seriesIndex": series_index,
                "priorMatchId": prior_match_id,
                "invitedUserIds": human_ids,
                "priorAiUserIds": ai_ids,
            }
        )
    except AppError as err:
        return err.to_http_response()


def _handle_resolve(res: HttpResponseContract):
    try:
        purge_expired_invite_notifications()
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
                customlog(
                    f"friend_match_invite: resolve not_found invite_id={invite_id}"
                )
            raise AppError(friend_match_inviteNotFound)

        invited_is_ai = is_ai_user(rec.invited_user_id)
        if LOGGING_SWITCH:
            customlog(
                f"friend_match_invite: resolve invite_id={invite_id} "
                f"invited={rec.invited_user_id} is_ai={invited_is_ai} "
                f"kind={rec.kind}"
            )

        payload = {
            "invitedUserId": rec.invited_user_id,
            "invitedUserIds": rec.all_invited_user_ids(),
            "isAi": invited_is_ai,
            "kind": rec.kind,
        }
        if rec.series_id:
            payload["seriesId"] = rec.series_id
        if rec.series_index is not None:
            payload["seriesIndex"] = rec.series_index
        if rec.prior_match_id:
            payload["priorMatchId"] = rec.prior_match_id
        return res.json_ok(payload)
    except AppError as err:
        return err.to_http_response()
    except (TypeError, ValueError):
        return AppError(
            friend_match_inviteInvalidRequest,
            message="Invalid request payload",
        ).to_http_response()


def _handle_cancel(res: HttpResponseContract):
    """Dart invite lobby timeout / cancel — drop invite + guest notification."""
    try:
        body = parse_json_body()
        invite_id = str(body.get("inviteId", "")).strip()
        if not invite_id:
            raise AppError(
                friend_match_inviteInvalidRequest,
                message="inviteId is required",
            )

        rec = cancel_invite_and_notification(invite_id)
        if LOGGING_SWITCH:
            customlog(
                f"friend_match_invite: cancel invite_id={invite_id} "
                f"found={rec is not None}"
            )
        return res.json_ok({"inviteId": invite_id, "cancelled": True})
    except AppError as err:
        return err.to_http_response()
    except (TypeError, ValueError):
        return AppError(
            friend_match_inviteInvalidRequest,
            message="Invalid request payload",
        ).to_http_response()
