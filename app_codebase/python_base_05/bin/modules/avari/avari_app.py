"""Avari HTTP routes (authuser read + Kin claim)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id
from modules.auth.auth_service import parse_json_body
from modules.avari.avari_errors import INVALID_QUERY
from modules.avari.avari_service import (
    claim_kin,
    get_avari_profile,
    verify_slammers_for_seats,
)
from modules.avari.kin_backgrounds import list_kin_backgrounds


def register_avari_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get("/avari/profile", lambda: _handle_profile(res))
    routes.authuser_get(
        "/avari/kin/backgrounds",
        lambda: _handle_kin_backgrounds(res),
    )
    routes.authuser_post("/avari/kin", lambda: _handle_claim_kin(res))
    routes.service_post("/avari/verify_slammers", lambda: _handle_verify_slammers(res))


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


def _handle_kin_backgrounds(res: HttpResponseContract):
    try:
        _require_user_id()
        return res.json_ok(list_kin_backgrounds())
    except AppError as err:
        return err.to_http_response()


def _handle_claim_kin(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        return res.json_ok(claim_kin(user_id, body))
    except AppError as err:
        return err.to_http_response()


def _handle_verify_slammers(res: HttpResponseContract):
    try:
        body = parse_json_body()
        seats = body.get("seats")
        if seats is not None and not isinstance(seats, list):
            raise AppError(INVALID_QUERY, message="seats must be a list")
        return res.json_ok(
            verify_slammers_for_seats(seats if isinstance(seats, list) else [])
        )
    except AppError as err:
        return err.to_http_response()
