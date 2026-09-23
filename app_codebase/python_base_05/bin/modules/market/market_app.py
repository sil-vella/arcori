"""Market HTTP routes (authuser slammer list / purchase / recharge)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id
from core.state.session_scope import session_scope
from modules.auth.auth_service import parse_json_body
from modules.market.market_errors import INVALID_QUERY
from modules.market.market_service import (
    list_market_slammers,
    parse_design_id_body,
    purchase_slammer,
    recharge_slammer,
)


def register_market_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get("/market/slammers", lambda: _handle_list(res))
    routes.authuser_post("/market/slammers/purchase", lambda: _handle_purchase(res))
    routes.authuser_post("/market/slammers/recharge", lambda: _handle_recharge(res))


def _require_user_id() -> str:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    return user_id


def _handle_list(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        with session_scope() as session:
            return res.json_ok(list_market_slammers(session, user_id=user_id))
    except AppError as err:
        return err.to_http_response()


def _handle_purchase(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        design_id = parse_design_id_body(body)
        with session_scope() as session:
            return res.json_ok(
                purchase_slammer(session, user_id=user_id, design_id=design_id)
            )
    except AppError as err:
        return err.to_http_response()


def _handle_recharge(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        design_id = parse_design_id_body(body)
        with session_scope() as session:
            return res.json_ok(
                recharge_slammer(session, user_id=user_id, design_id=design_id)
            )
    except AppError as err:
        return err.to_http_response()
