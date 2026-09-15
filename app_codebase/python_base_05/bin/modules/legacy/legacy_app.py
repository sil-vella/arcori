"""Legacy HTTP routes (authuser + service)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id, get_current_request
from core.utils.dev_logger import customlog
from modules.auth.auth_service import parse_json_body
from modules.legacy.legacy_errors import INVALID_QUERY
from modules.legacy.legacy_service import (
    decline_offer,
    fulfill_from_website,
    get_offer,
    preserve_complete,
    preserve_start,
    tick_expire_offers,
)

LOGGING_SWITCH = True


def register_legacy_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get("/legacy/offer", lambda: _handle_offer(res))
    routes.authuser_post("/legacy/decline", lambda: _handle_decline(res))
    routes.authuser_post(
        "/legacy/preserve/start", lambda: _handle_preserve_start(res)
    )
    routes.authuser_post(
        "/legacy/preserve/complete", lambda: _handle_preserve_complete(res)
    )
    routes.service_post("/legacy/fulfill", lambda: _handle_fulfill(res))
    routes.service_post("/legacy/tick", lambda: _handle_tick(res))


def _require_user_id() -> str:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    return user_id


def _handle_offer(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        request = get_current_request()
        design_id = ""
        if request is not None:
            design_id = (
                request.query_params.get("designId")
                or request.query_params.get("id")
                or ""
            )
        out = get_offer(user_id, design_id)
        if LOGGING_SWITCH:
            customlog(
                f"legacy: GET offer user={user_id} design={design_id} "
                f"phase={out.get('phase')} "
                f"canFirst={out.get('canPreserveAsFirstOffer')} "
                f"canLeader={out.get('canPreserveAsLeader')}"
            )
        return res.json_ok(out)
    except AppError as err:
        return err.to_http_response()


def _handle_decline(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        if LOGGING_SWITCH:
            customlog(f"legacy: POST decline user={user_id}")
        return res.json_ok(decline_offer(user_id, parse_json_body()))
    except AppError as err:
        return err.to_http_response()


def _handle_preserve_start(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        if LOGGING_SWITCH:
            customlog(f"legacy: POST preserve/start user={user_id}")
        return res.json_ok(preserve_start(user_id, parse_json_body()))
    except AppError as err:
        return err.to_http_response()


def _handle_preserve_complete(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        if LOGGING_SWITCH:
            customlog(
                f"legacy: POST preserve/complete user={user_id} "
                f"intentId={(body or {}).get('intentId')} "
                f"orderId={(body or {}).get('orderId')}"
            )
        return res.json_ok(preserve_complete(user_id, body))
    except AppError as err:
        return err.to_http_response()


def _handle_fulfill(res: HttpResponseContract):
    try:
        body = parse_json_body()
        if LOGGING_SWITCH:
            customlog(
                f"legacy: POST fulfill orderId={(body or {}).get('orderId')} "
                f"intentId={(body or {}).get('intentId')}"
            )
        return res.json_ok(fulfill_from_website(body))
    except AppError as err:
        return err.to_http_response()


def _handle_tick(res: HttpResponseContract):
    try:
        out = tick_expire_offers()
        if LOGGING_SWITCH:
            customlog(f"legacy: tick expiredOffers={out.get('expiredOffers')}")
        return res.json_ok(out)
    except AppError as err:
        return err.to_http_response()
