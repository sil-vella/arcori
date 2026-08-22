"""Notification business logic — create, list, read, delete."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from core.errors.app_error import AppError
from core.notifications.reply_registry import dispatch_reply
from core.notifications.response_config import (
    extract_response_config,
    validate_data_response,
)
from core.notifications.response_types import RESPONSE_TYPE_REPLY
from core.notifications.subtype_registry import require_subtype_spec
from core.state.session_scope import session_scope
from core.state.state_registry import inbox_broadcaster
from core.utils.dev_logger import customlog
from modules.auth.auth_service import parse_json_body
from modules.notifications import notification_repository as repo
from modules.notifications.notification_errors import (
    INVALID_CATEGORY,
    INVALID_NOTIFICATION_TYPE,
    INVALID_REQUEST,
    INVALID_RESPONSE,
    NOT_FOUND,
    NOT_REPLY_TYPE,
)

LOGGING_SWITCH = True

_MAX_LIST_LIMIT = 100
_MAX_MARK_READ = 100
_MAX_GLOBAL_MARK_READ = 50
_GLOBAL_ID_PREFIX = "glob_"


def _parse_uuid(value: str, *, field: str) -> uuid.UUID:
    try:
        return uuid.UUID(str(value).strip())
    except (ValueError, AttributeError) as exc:
        raise AppError(INVALID_REQUEST, message=f"Invalid {field}") from exc


def _serialize_user_row(row) -> dict[str, Any]:
    return {
        "id": str(row.id),
        "origin": "user",
        "source": row.source,
        "type": row.type,
        "category": row.category,
        "subtype": row.subtype,
        "msg_id": row.msg_id,
        "title": row.title,
        "body": row.body,
        "data": row.data or {},
        "responses": row.responses or [],
        "read_at": row.read_at.isoformat() if row.read_at else None,
        "created_at": row.created_at.isoformat(),
    }


def _serialize_global_row(row, *, user_read: bool) -> dict[str, Any]:
    global_id = str(row.id)
    return {
        "id": f"{_GLOBAL_ID_PREFIX}{global_id.replace('-', '')}",
        "global_id": global_id,
        "origin": "global",
        "source": row.source,
        "type": row.type,
        "category": row.category,
        "subtype": row.subtype,
        "msg_id": row.msg_id,
        "title": row.title,
        "body": row.body,
        "data": row.data or {},
        "responses": row.responses or [],
        "user_read": user_read,
        "read_at": datetime.now(timezone.utc).isoformat() if user_read else None,
        "created_at": row.created_at.isoformat(),
    }


def _normalize_type(value: str) -> str:
    normalized = str(value or "instant").strip().lower()
    if not repo.is_valid_notification_type(normalized):
        raise AppError(INVALID_NOTIFICATION_TYPE)
    return normalized


def _parse_global_id(raw: str) -> uuid.UUID:
    value = str(raw).strip()
    if value.startswith(_GLOBAL_ID_PREFIX):
        value = value[len(_GLOBAL_ID_PREFIX) :]
        if len(value) == 32:
            value = f"{value[:8]}-{value[8:12]}-{value[12:16]}-{value[16:20]}-{value[20:]}"
    return _parse_uuid(value, field="global_message_id")


def _normalize_category(value: str | None) -> str:
    normalized = str(value or "").strip()
    if not normalized:
        raise AppError(INVALID_CATEGORY)
    return normalized


def _normalize_subtype(value: str | None) -> str:
    normalized = str(value or "").strip()
    if not normalized:
        raise AppError(INVALID_REQUEST, message="subtype is required")
    return normalized


def create_for_user(
    user_id: str,
    *,
    source: str,
    notification_type: str,
    title: str,
    body: str,
    category: str,
    subtype: str,
    msg_id: str | None = None,
    data: dict[str, Any] | None = None,
    responses: list[dict[str, Any]] | None = None,
) -> str:
    uid = _parse_uuid(user_id, field="user_id")
    source_value = str(source or "").strip()
    title_value = str(title or "").strip()
    body_value = str(body or "").strip()
    if not source_value or not title_value or not body_value:
        raise AppError(INVALID_REQUEST, message="source, title, and body are required")

    category_value = _normalize_category(category)
    subtype_value = _normalize_subtype(subtype)
    spec = require_subtype_spec(
        source=source_value,
        category=category_value,
        subtype=subtype_value,
    )

    normalized_type = _normalize_type(notification_type)
    if spec.default_delivery is not None and normalized_type != spec.default_delivery:
        raise AppError(
            INVALID_NOTIFICATION_TYPE,
            message=f"type must be {spec.default_delivery} for this subtype",
        )

    normalized_data = validate_data_response(
        data,
        source=source_value,
        category=category_value,
        subtype=subtype_value,
    )

    with session_scope() as session:
        row = repo.insert_user_notification(
            session,
            user_id=uid,
            source=source_value,
            notification_type=normalized_type,
            title=title_value,
            body=body_value,
            category=category_value,
            subtype=subtype_value,
            msg_id=msg_id,
            data=normalized_data,
            responses=responses,
        )
        message_id = str(row.id)

    if LOGGING_SWITCH:
        customlog(
            f"notifications: create_for_user user={uid} source={source_value} "
            f"type={normalized_type} category={category_value} subtype={subtype_value} "
            f"message_id={message_id} msg_id={msg_id or '-'}"
        )

    inbox_broadcaster.notify_inbox_changed(str(uid))
    return message_id


def create_from_request_body(body: dict[str, Any]) -> dict[str, Any]:
    message_id = create_for_user(
        str(body.get("user_id", "")),
        source=str(body.get("source", "")),
        notification_type=str(body.get("type", "instant")),
        title=str(body.get("title", "")),
        body=str(body.get("body", "")),
        category=str(body.get("category", "")),
        subtype=str(body.get("subtype", "")),
        msg_id=body.get("msg_id"),
        data=body.get("data") if isinstance(body.get("data"), dict) else {},
        responses=body.get("responses") if isinstance(body.get("responses"), list) else [],
    )
    return {"message_id": message_id}


def create_from_service_request() -> dict[str, Any]:
    return create_from_request_body(parse_json_body())


def list_messages_for_user(
    user_id: str,
    *,
    limit: int = 50,
    offset: int = 0,
    unread_only: bool = False,
) -> dict[str, Any]:
    uid = _parse_uuid(user_id, field="user_id")
    safe_limit = max(1, min(limit, _MAX_LIST_LIMIT))
    safe_offset = max(0, offset)

    with session_scope() as session:
        rows = repo.list_user_notifications(
            session,
            uid,
            limit=safe_limit,
            offset=safe_offset,
            unread_only=unread_only,
        )
        unread_count = repo.count_unread_user_notifications(session, uid)
        messages = [_serialize_user_row(row) for row in rows]

    return {
        "messages": messages,
        "unread_count": unread_count,
    }


def list_globals_for_user(user_id: str) -> dict[str, Any]:
    uid = _parse_uuid(user_id, field="user_id")

    with session_scope() as session:
        globals_rows = repo.list_active_global_notifications(session)
        read_ids = repo.global_read_ids_for_user(
            session,
            uid,
            [row.id for row in globals_rows],
        )
        messages = [
            _serialize_global_row(row, user_read=row.id in read_ids)
            for row in globals_rows
        ]

    unread_count = sum(1 for message in messages if not message["user_read"])
    return {"messages": messages, "unread_count": unread_count}


def mark_read_for_user(user_id: str, message_ids: list[str]) -> dict[str, Any]:
    uid = _parse_uuid(user_id, field="user_id")
    ids = [_parse_uuid(value, field="message_id") for value in message_ids[:_MAX_MARK_READ]]

    with session_scope() as session:
        updated = repo.mark_user_notifications_read(session, uid, ids)

    return {"updated": updated}


def mark_global_read_for_user(user_id: str, global_message_ids: list[str]) -> dict[str, Any]:
    uid = _parse_uuid(user_id, field="user_id")
    global_ids: list[uuid.UUID] = []
    for raw in global_message_ids[:_MAX_GLOBAL_MARK_READ]:
        global_ids.append(_parse_global_id(raw))

    with session_scope() as session:
        updated = repo.mark_global_notifications_read(session, uid, global_ids)

    return {"updated": updated}


def delete_for_user(user_id: str, message_ids: list[str]) -> dict[str, Any]:
    uid = _parse_uuid(user_id, field="user_id")
    ids = [_parse_uuid(value, field="message_id") for value in message_ids[:_MAX_MARK_READ]]

    with session_scope() as session:
        deleted = repo.soft_delete_user_notifications(session, uid, ids)

    return {"deleted": deleted}


def parse_message_ids_from_body(body: dict[str, Any]) -> list[str]:
    raw = body.get("message_ids")
    if not isinstance(raw, list):
        raise AppError(INVALID_REQUEST, message="message_ids must be a list")
    return [str(item) for item in raw if str(item).strip()]


def parse_global_message_ids_from_body(body: dict[str, Any]) -> list[str]:
    raw = body.get("global_message_ids")
    if not isinstance(raw, list):
        raise AppError(INVALID_REQUEST, message="global_message_ids must be a list")
    return [str(item) for item in raw if str(item).strip()]


def handle_response(
    user_id: str,
    *,
    message_id: str | None = None,
    global_message_id: str | None = None,
    option_key: str,
) -> dict[str, Any]:
    uid = _parse_uuid(user_id, field="user_id")
    key = str(option_key or "").strip().lower()
    if not key:
        raise AppError(INVALID_REQUEST, message="option_key is required")

    has_user = bool(str(message_id or "").strip())
    has_global = bool(str(global_message_id or "").strip())
    if has_user == has_global:
        raise AppError(
            INVALID_REQUEST,
            message="Provide exactly one of message_id or global_message_id",
        )

    with session_scope() as session:
        if has_user:
            mid = _parse_uuid(str(message_id), field="message_id")
            row = repo.get_user_notification(session, uid, mid)
            if row is None:
                raise AppError(NOT_FOUND)
            message = _serialize_user_row(row)
            mark_read = lambda: repo.mark_user_notifications_read(session, uid, [mid])
        else:
            gid = _parse_global_id(str(global_message_id))
            row = repo.get_active_global_notification(session, gid)
            if row is None:
                raise AppError(NOT_FOUND)
            message = _serialize_global_row(row, user_read=False)
            mark_read = lambda: repo.mark_global_notifications_read(session, uid, [gid])

        response = extract_response_config(message.get("data"))
        if response is None or response.get("type") != RESPONSE_TYPE_REPLY:
            raise AppError(NOT_REPLY_TYPE)

        valid_keys = {
            str(option.get("key", "")).strip().lower()
            for option in response.get("options", [])
            if isinstance(option, dict)
        }
        if key not in valid_keys:
            raise AppError(INVALID_RESPONSE)

        result = dispatch_reply(
            source=message["source"],
            user_id=str(uid),
            message=message,
            option_key=key,
        )

        if response.get("mark_read_on_success", True):
            mark_read()

    payload: dict[str, Any] = {"success": True}
    data = result.get("data")
    if data is not None:
        payload["data"] = data
    return payload


def handle_response_from_body(user_id: str, body: dict[str, Any]) -> dict[str, Any]:
    return handle_response(
        user_id,
        message_id=body.get("message_id"),
        global_message_id=body.get("global_message_id"),
        option_key=str(body.get("option_key", "")),
    )
