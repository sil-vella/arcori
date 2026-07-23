"""Ops HTTP routes — drain enter/exit/status (service tier)."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from modules.ops.ops_service import drain_status, enter_drain, exit_drain


def register_ops_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.service_post("/ops/enter-drain", lambda: _handle_enter(res))
    routes.service_post("/ops/exit-drain", lambda: _handle_exit(res))
    routes.service_get("/ops/drain-status", lambda: _handle_status(res))


def _handle_enter(res: HttpResponseContract):
    try:
        payload = enter_drain()
    except AppError as err:
        return err.to_http_response()
    return res.json_ok(payload)


def _handle_exit(res: HttpResponseContract):
    try:
        payload = exit_drain()
    except AppError as err:
        return err.to_http_response()
    return res.json_ok(payload)


def _handle_status(res: HttpResponseContract):
    try:
        payload = drain_status()
    except AppError as err:
        return err.to_http_response()
    return res.json_ok(payload)
