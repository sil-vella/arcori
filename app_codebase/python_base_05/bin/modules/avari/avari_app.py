"""Avari HTTP routes (authuser read)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id
from modules.avari.avari_errors import INVALID_QUERY
from modules.avari.avari_service import get_avari_profile


def register_avari_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get("/avari/profile", lambda: _handle_profile(res))


def _require_user_id() -> str:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    return user_id


def _handle_profile(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        return res.json_ok(get_avari_profile(user_id))
    except AppError as err:
        return err.to_http_response()
