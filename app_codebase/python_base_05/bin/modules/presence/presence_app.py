"""Presence HTTP routes."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id, get_current_request
from modules.presence.presence_errors import INVALID_REQUEST
from modules.presence.presence_service import parse_user_ids, presence_for_users


def register_presence_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get(
        "/presence",
        lambda: _handle_batch_presence(res),
    )


def _require_user_id() -> str:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(INVALID_REQUEST, message="Unauthorized")
    return user_id


def _handle_batch_presence(res: HttpResponseContract):
    try:
        _require_user_id()
        request = get_current_request()
        raw = None
        if request is not None:
            raw = request.query_params.get("user_ids")
        user_ids = parse_user_ids(raw)
        payload = presence_for_users(user_ids)
    except AppError as err:
        return err.to_http_response()
    return res.json_ok(payload)
