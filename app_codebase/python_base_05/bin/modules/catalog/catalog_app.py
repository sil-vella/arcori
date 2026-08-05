"""Catalog HTTP routes (authuser reads + service batch for Dart freeze)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id, get_current_request
from modules.auth.auth_service import parse_json_body
from modules.catalog.catalog_errors import INVALID_QUERY
from modules.catalog.catalog_service import (
    get_design,
    get_designs_batch,
    get_index,
    get_meta,
    get_theme,
)


def register_catalog_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    # Exact-match router: use query params for theme/design ids (no {path} params).
    routes.authuser_get("/catalog/meta", lambda: _handle_meta(res))
    routes.authuser_get("/catalog/index", lambda: _handle_index(res))
    routes.authuser_get("/catalog/theme", lambda: _handle_theme(res))
    routes.authuser_get("/catalog/design", lambda: _handle_design(res))
    routes.service_post("/catalog/designs", lambda: _handle_designs_batch(res))


def _require_user_id() -> str:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(INVALID_QUERY, message="Unauthorized")
    return user_id


def _handle_meta(res: HttpResponseContract):
    try:
        _require_user_id()
        return res.json_ok(get_meta())
    except AppError as err:
        return err.to_http_response()


def _handle_index(res: HttpResponseContract):
    try:
        _require_user_id()
        request = get_current_request()
        series = None
        theme = None
        subtheme = None
        circulating = False
        limit: int | None = None
        offset = 0
        if request is not None:
            series = request.query_params.get("series") or None
            theme = request.query_params.get("theme") or None
            subtheme = request.query_params.get("subtheme") or None
            circulating = request.query_params.get("circulating", "").lower() in {
                "1",
                "true",
                "yes",
            }
            if "limit" in request.query_params:
                limit = int(request.query_params.get("limit", "0"))
            if "offset" in request.query_params:
                offset = int(request.query_params.get("offset", "0"))
        return res.json_ok(
            get_index(
                series=series,
                theme=theme,
                subtheme=subtheme,
                circulating=circulating,
                limit=limit,
                offset=offset,
            )
        )
    except AppError as err:
        return err.to_http_response()
    except ValueError:
        return AppError(INVALID_QUERY, message="Invalid query params").to_http_response()


def _handle_theme(res: HttpResponseContract):
    try:
        _require_user_id()
        request = get_current_request()
        code = ""
        if request is not None:
            code = (
                request.query_params.get("code")
                or request.query_params.get("theme_code")
                or ""
            )
        return res.json_ok(get_theme(code))
    except AppError as err:
        return err.to_http_response()


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
        return res.json_ok(get_design(internal_id))
    except AppError as err:
        return err.to_http_response()


def _handle_designs_batch(res: HttpResponseContract):
    try:
        body = parse_json_body()
        ids = body.get("ids")
        if ids is not None and not isinstance(ids, list):
            raise AppError(INVALID_QUERY, message="ids must be a list")
        return res.json_ok(get_designs_batch(ids if isinstance(ids, list) else None))
    except AppError as err:
        return err.to_http_response()
