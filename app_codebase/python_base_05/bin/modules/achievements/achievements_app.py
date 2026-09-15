"""Achievements HTTP routes (authuser catalog + unlocked)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.state.session_scope import session_scope
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id
from modules.achievements.achievements_errors import INVALID_QUERY
from modules.achievements.achievements_service import (
    get_catalog_payload,
    get_unlocked_payload,
)


def register_achievements_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get("/achievements/catalog", lambda: _handle_catalog(res))
    routes.authuser_get("/achievements/unlocked", lambda: _handle_unlocked(res))


def _require_user_id() -> str:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    return user_id


def _handle_catalog(res: HttpResponseContract):
    try:
        _require_user_id()
        return res.json_ok(get_catalog_payload())
    except AppError as err:
        return err.to_http_response()


def _handle_unlocked(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        with session_scope() as session:
            return res.json_ok(get_unlocked_payload(session, user_id))
    except AppError as err:
        return err.to_http_response()
