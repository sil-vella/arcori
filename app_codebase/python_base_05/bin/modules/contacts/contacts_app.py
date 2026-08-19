"""Contacts module HTTP routes (authuser): search + mutual add/remove."""

from __future__ import annotations

import uuid

from core.errors.app_error import AppError
from core.http.contracts.register_route_contract import ApplicationRouteSink
from core.http.contracts.response_contract import HttpResponseContract
from core.http.request_context import get_auth_user_id, get_current_request
from modules.auth.auth_service import parse_json_body
from modules.contacts.contacts_errors import INVALID_REQUEST, UNAUTHORIZED
from modules.contacts.contacts_service import (
    add_contact_mutual,
    list_contacts_for_user,
    remove_contact_mutual,
    search_users_by_username,
)


def register_contacts_routes(
    routes: ApplicationRouteSink,
    res: HttpResponseContract,
) -> None:
    routes.authuser_get("/contacts/search", lambda: _handle_search(res))
    routes.authuser_get("/contacts/list", lambda: _handle_list(res))
    routes.authuser_post("/contacts/add", lambda: _handle_add(res))
    routes.authuser_delete("/contacts/remove", lambda: _handle_remove(res))


def _require_user_uuid() -> uuid.UUID:
    user_id = get_auth_user_id()
    if not user_id:
        raise AppError(UNAUTHORIZED)
    try:
        return uuid.UUID(str(user_id).strip())
    except ValueError as exc:
        raise AppError(UNAUTHORIZED, message="Invalid auth user id") from exc


def _handle_search(res: HttpResponseContract):
    try:
        user_id = _require_user_uuid()
        request = get_current_request()
        query = ""
        limit = 20
        if request is not None:
            query = request.query_params.get("query", "") or ""
            if "limit" in request.query_params:
                limit = int(request.query_params.get("limit", "20") or "20")

        users = search_users_by_username(
            user_id=user_id,
            query=query,
            limit=limit,
        )
        return res.json_ok({"users": users})
    except AppError as err:
        return err.to_http_response()
    except ValueError:
        return AppError(
            INVALID_REQUEST,
            message="Invalid query params",
        ).to_http_response()


def _handle_list(res: HttpResponseContract):
    try:
        user_id = _require_user_uuid()
        contacts = list_contacts_for_user(
            user_id=user_id,
        )
        return res.json_ok({"contacts": contacts})
    except AppError as err:
        return err.to_http_response()


def _handle_add(res: HttpResponseContract):
    try:
        user_id = _require_user_uuid()
        body = parse_json_body()
        contact_user_id_raw = body.get("contact_user_id")

        add_contact_mutual(
            user_id=user_id,
            contact_user_id=uuid.UUID(str(contact_user_id_raw)),
        )

        # Return updated single contact view (UI can also call /contacts/list).
        return res.json_ok({"ok": True})
    except AppError as err:
        return err.to_http_response()
    except (TypeError, ValueError):
        return AppError(INVALID_REQUEST, message="contact_user_id must be a UUID").to_http_response()


def _handle_remove(res: HttpResponseContract):
    try:
        user_id = _require_user_uuid()
        request = get_current_request()
        if request is None:
            raise AppError(INVALID_REQUEST, message="Request context missing")
        contact_user_id = request.query_params.get("contact_user_id")
        if not contact_user_id:
            raise AppError(INVALID_REQUEST, message="contact_user_id missing")

        remove_contact_mutual(
            user_id=user_id,
            contact_user_id=uuid.UUID(str(contact_user_id)),
        )
        return res.json_ok({"ok": True})
    except AppError as err:
        return err.to_http_response()
    except ValueError:
        return AppError(INVALID_REQUEST, message="contact_user_id must be a UUID").to_http_response()

