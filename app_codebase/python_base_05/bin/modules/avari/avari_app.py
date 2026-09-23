"""Avari HTTP routes (authuser read + Kin claim + match fee/finalize)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id
from modules.auth.auth_service import parse_json_body
from modules.avari.avari_errors import INVALID_QUERY
from modules.avari.avari_service import (
    claim_kin,
    finalize_match,
    get_avari_profile,
    get_mastery_recent,
    pay_match_fee,
    refund_match_fee,
    spend_slammer_charge,
    verify_slammers_for_seats,
)
from modules.avari.kin_backgrounds import list_kin_backgrounds


def register_avari_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get("/avari/profile", lambda: _handle_profile(res))
    routes.authuser_get(
        "/avari/mastery/recent",
        lambda: _handle_mastery_recent(res),
    )
    routes.authuser_get(
        "/avari/kin/backgrounds",
        lambda: _handle_kin_backgrounds(res),
    )
    routes.authuser_post("/avari/kin", lambda: _handle_claim_kin(res))
    routes.authuser_post(
        "/avari/match/pay_fee",
        lambda: _handle_match_pay_fee(res),
    )
    routes.authuser_post(
        "/avari/match/refund_fee",
        lambda: _handle_match_refund_fee(res),
    )
    routes.authuser_post(
        "/avari/match/finalize",
        lambda: _handle_match_finalize(res),
    )
    routes.service_post("/avari/verify_slammers", lambda: _handle_verify_slammers(res))
    routes.service_post(
        "/avari/spend_slammer_charge",
        lambda: _handle_spend_slammer_charge_service(res),
    )
    routes.authuser_post(
        "/avari/spend_slammer_charge",
        lambda: _handle_spend_slammer_charge_authuser(res),
    )


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


def _handle_mastery_recent(res: HttpResponseContract):
    try:
        from core.http.request_context import get_current_request

        user_id = _require_user_id()
        request = get_current_request()
        limit = 5
        if request is not None:
            try:
                limit = int(request.query_params.get("limit", "5"))
            except ValueError:
                limit = 5
        return res.json_ok(get_mastery_recent(user_id, limit=limit))
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


def _handle_match_pay_fee(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        return res.json_ok(pay_match_fee(user_id, body))
    except AppError as err:
        return err.to_http_response()


def _handle_match_refund_fee(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        return res.json_ok(refund_match_fee(user_id, body))
    except AppError as err:
        return err.to_http_response()


def _handle_match_finalize(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        return res.json_ok(finalize_match(user_id, body))
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


def _handle_spend_slammer_charge_service(res: HttpResponseContract):
    try:
        body = parse_json_body()
        if not isinstance(body, dict):
            raise AppError(INVALID_QUERY, message="JSON body required")
        user_id = str(body.get("userId") or body.get("user_id") or "").strip()
        design_id = str(body.get("designId") or body.get("design_id") or "").strip()
        match_id = str(body.get("matchId") or body.get("match_id") or "").strip() or None
        intent_id = (
            str(body.get("intentId") or body.get("intent_id") or "").strip() or None
        )
        if not user_id or not design_id:
            raise AppError(INVALID_QUERY, message="userId and designId required")
        return res.json_ok(
            spend_slammer_charge(
                user_id=user_id,
                design_id=design_id,
                match_id=match_id,
                intent_id=intent_id,
            )
        )
    except AppError as err:
        return err.to_http_response()


def _handle_spend_slammer_charge_authuser(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        if not isinstance(body, dict):
            raise AppError(INVALID_QUERY, message="JSON body required")
        design_id = str(body.get("designId") or body.get("design_id") or "").strip()
        match_id = str(body.get("matchId") or body.get("match_id") or "").strip() or None
        intent_id = (
            str(body.get("intentId") or body.get("intent_id") or "").strip() or None
        )
        if not design_id:
            raise AppError(INVALID_QUERY, message="designId required")
        return res.json_ok(
            spend_slammer_charge(
                user_id=user_id,
                design_id=design_id,
                match_id=match_id,
                intent_id=intent_id,
            )
        )
    except AppError as err:
        return err.to_http_response()