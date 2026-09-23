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
    get_museum_banner,
    get_museum_item,
    get_offer,
    list_museum,
    list_museum_series,
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
    routes.authuser_get("/museum", lambda: _handle_museum_list(res))
    routes.authuser_get("/museum/series", lambda: _handle_museum_series(res))
    routes.authuser_get("/museum/banner", lambda: _handle_museum_banner(res))
    routes.authuser_get("/museum/item", lambda: _handle_museum_item(res))
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


def _handle_museum_list(res: HttpResponseContract):
    try:
        _require_user_id()
        request = get_current_request()
        outcome = "all"
        q = None
        series = None
        limit = 30
        cursor = None
        if request is not None:
            outcome = request.query_params.get("outcome") or "all"
            q = request.query_params.get("q")
            series = request.query_params.get("series")
            raw_limit = request.query_params.get("limit")
            if raw_limit:
                try:
                    limit = int(raw_limit)
                except ValueError:
                    raise AppError(INVALID_QUERY, message="limit must be an integer")
            cursor = request.query_params.get("cursor")
        out = list_museum(
            outcome=outcome, q=q, series=series, limit=limit, cursor=cursor
        )
        if LOGGING_SWITCH:
            customlog(
                f"legacy: GET museum outcome={outcome} series={series!r} q={q!r} "
                f"items={len(out.get('items') or [])}"
            )
        return res.json_ok(out)
    except AppError as err:
        return err.to_http_response()


def _handle_museum_series(res: HttpResponseContract):
    try:
        _require_user_id()
        request = get_current_request()
        outcome = "preserved"
        if request is not None:
            outcome = request.query_params.get("outcome") or "preserved"
        out = list_museum_series(outcome=outcome)
        if LOGGING_SWITCH:
            customlog(
                f"legacy: GET museum/series outcome={outcome} "
                f"count={len(out.get('series') or [])}"
            )
        return res.json_ok(out)
    except AppError as err:
        return err.to_http_response()


def _handle_museum_banner(res: HttpResponseContract):
    try:
        _require_user_id()
        out = get_museum_banner()
        if LOGGING_SWITCH:
            items = out.get("items") if isinstance(out, dict) else None
            count = len(items) if isinstance(items, list) else 0
            customlog(f"legacy: GET museum/banner items={count}")
        return res.json_ok(out)
    except AppError as err:
        return err.to_http_response()


def _handle_museum_item(res: HttpResponseContract):
    try:
        _require_user_id()
        request = get_current_request()
        design_id = ""
        generation_number = 0
        if request is not None:
            design_id = (
                request.query_params.get("designId")
                or request.query_params.get("design_id")
                or ""
            )
            raw_gen = (
                request.query_params.get("generationNumber")
                or request.query_params.get("generation_number")
                or "0"
            )
            try:
                generation_number = int(raw_gen)
            except ValueError:
                raise AppError(
                    INVALID_QUERY, message="generationNumber must be an integer"
                )
        out = get_museum_item(
            design_id=design_id, generation_number=generation_number
        )
        if LOGGING_SWITCH:
            customlog(
                f"legacy: GET museum/item design={design_id} gen={generation_number}"
            )
        return res.json_ok(out)
    except AppError as err:
        return err.to_http_response()
