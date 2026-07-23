"""Presence query business logic."""

from __future__ import annotations

import uuid

from core.errors.app_error import AppError
from core.presence import user_presence_reader
from modules.presence.presence_errors import INVALID_REQUEST

_MAX_BATCH = 50


def _parse_uuid(value: str) -> uuid.UUID:
    try:
        return uuid.UUID(str(value).strip())
    except (ValueError, AttributeError) as exc:
        raise AppError(INVALID_REQUEST, message="Invalid user_id") from exc


def parse_user_ids(raw: str | None) -> list[str]:
    if not raw or not str(raw).strip():
        raise AppError(INVALID_REQUEST, message="user_ids query param is required")
    parts = [part.strip() for part in str(raw).split(",") if part.strip()]
    if not parts:
        raise AppError(INVALID_REQUEST, message="user_ids must contain at least one id")
    if len(parts) > _MAX_BATCH:
        raise AppError(INVALID_REQUEST, message=f"At most {_MAX_BATCH} user_ids allowed")
    return [str(_parse_uuid(part)) for part in parts]


def presence_for_users(user_ids: list[str]) -> dict[str, dict[str, object]]:
    users: dict[str, dict[str, object]] = {}
    for user_id in user_ids:
        count = user_presence_reader.session_count(user_id)
        users[user_id] = {
            "online": count > 0,
            "session_count": count,
        }
    return {"users": users}
