"""Notification HTTP routes."""

from __future__ import annotations

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id, get_current_request
from modules.auth.auth_service import parse_json_body
from modules.notifications.notification_errors import INVALID_REQUEST
from modules.notifications.notification_service import (
    create_from_service_request,
    delete_for_user,
    handle_response_from_body,
    list_globals_for_user,
    list_messages_for_user,
    mark_global_read_for_user,
    mark_read_for_user,
    parse_global_message_ids_from_body,
    parse_message_ids_from_body,
)


def register_notification_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.service_post(
        "/notifications/create",
        lambda: _handle_service_create(res),
    )
    routes.authuser_get(
        "/notifications/messages",
        lambda: _handle_list_messages(res),
    )
    routes.authuser_get(
        "/notifications/globals",
        lambda: _handle_list_globals(res),
    )
    routes.authuser_post(
        "/notifications/mark-read",
        lambda: _handle_mark_read(res),
    )
    routes.authuser_post(
        "/notifications/global-mark-read",
        lambda: _handle_global_mark_read(res),
    )
    routes.authuser_post(
        "/notifications/delete",
        lambda: _handle_delete(res),
    )
    routes.authuser_post(
        "/notifications/response",
        lambda: _handle_response(res),
    )


def _require_user_id() -> str:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(INVALID_REQUEST, message="Unauthorized")
    return user_id


def _handle_service_create(res: HttpResponseContract):
    try:
        payload = create_from_service_request()
    except AppError as err:
        return err.to_http_response()
    return res.json_ok(payload)


def _handle_list_messages(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        request = get_current_request()
        limit = 50
        offset = 0
        unread_only = False
        if request is not None:
            limit = int(request.query_params.get("limit", "50"))
            offset = int(request.query_params.get("offset", "0"))
            unread_only = request.query_params.get("unread_only", "false").lower() in {
                "1",
                "true",
                "yes",
            }
        payload = list_messages_for_user(
            user_id,
            limit=limit,
            offset=offset,
            unread_only=unread_only,
        )
    except AppError as err:
        return err.to_http_response()
    except ValueError:
        return res.json_error(code="invalid_request", message="Invalid query params", status=400)
    return res.json_ok(payload)


def _handle_list_globals(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        payload = list_globals_for_user(user_id)
    except AppError as err:
        return err.to_http_response()
    return res.json_ok(payload)


def _handle_mark_read(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        message_ids = parse_message_ids_from_body(body)
        payload = mark_read_for_user(user_id, message_ids)
    except AppError as err:
        return err.to_http_response()
    return res.json_ok(payload)


def _handle_global_mark_read(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        global_message_ids = parse_global_message_ids_from_body(body)
        payload = mark_global_read_for_user(user_id, global_message_ids)
    except AppError as err:
        return err.to_http_response()
    return res.json_ok(payload)


def _handle_delete(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        message_ids = parse_message_ids_from_body(body)
        payload = delete_for_user(user_id, message_ids)
    except AppError as err:
        return err.to_http_response()
    return res.json_ok(payload)


def _handle_response(res: HttpResponseContract):
    try:
        user_id = _require_user_id()
        body = parse_json_body()
        payload = handle_response_from_body(user_id, body)
    except AppError as err:
        return err.to_http_response()
    return res.json_ok(payload)
