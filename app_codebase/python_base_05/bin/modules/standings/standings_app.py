"""Standings HTTP routes (authuser read)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id, get_current_request
from modules.standings.standings_errors import INVALID_QUERY
from modules.standings.standings_service import get_design_standings


def register_standings_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get("/standings/design", lambda: _handle_design(res))


def _require_user_id() -> str:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    return user_id


def _handle_design(res: HttpResponseContract):
    try:
        _require_user_id()
        request = get_current_request()
        internal_id = ""
        if request is not None:
            internal_id = (
                request.query_params.get("id")
                or request.query_params.get("internal_id")
                or ""
            )
        return res.json_ok(get_design_standings(internal_id))
    except AppError as err:
        return err.to_http_response()
