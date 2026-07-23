"""Example module routes — cache demo, service record, authuser reads."""

from __future__ import annotations

from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id
from modules.example_module.example_notifications import (
    create_demo_notifications_for_user,
)
from modules.example_module.example_service import (
    get_cached_demo_payload,
    recent_for_user,
    record_from_request,
)


def register_example_module_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.public_get(
        "/example/cached",
        lambda: res.json_ok(get_cached_demo_payload()),
    )
    routes.service_post(
        "/example_module/record",
        lambda: _handle_record(res),
    )
    routes.authuser_get(
        "/example_module/recent",
        lambda: _handle_recent(res),
    )
    routes.authuser_post(
        "/example_module/demo-notifications",
        lambda: _handle_demo_notifications(res),
    )


def _handle_record(res: HttpResponseContract):
    try:
        payload = record_from_request()
    except ValueError as exc:
        return res.json_error(
            code="invalid_request",
            message=str(exc),
            status=400,
        )
    return res.json_ok(payload)


def _handle_recent(res: HttpResponseContract):
    user_id = get_auth_user_id()
    if not user_id:
        return res.json_error(code="unauthorized", message="Unauthorized", status=401)
    return res.json_ok({"items": recent_for_user(user_id)})


def _handle_demo_notifications(res: HttpResponseContract):
    user_id = get_auth_user_id()
    if not user_id:
        return res.json_error(code="unauthorized", message="Unauthorized", status=401)
    payload = create_demo_notifications_for_user(user_id)
    return res.json_ok(payload)
