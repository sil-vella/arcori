"""Example module business logic — cache demo + durable records."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from core.cache import read_cache
from core.cache.cache_config import example_cache_ttl_seconds
from core.state.session_scope import session_scope
from modules.auth.auth_service import parse_json_body
from modules.example_module import example_repository
from modules.notifications.notification_service import create_for_user
from models.user_notification import NOTIFICATION_TYPE_INBOX

_EXAMPLE_CACHE_KEY = "example_module:demo:v1"
_RECENT_CACHE_PREFIX = "example_module:recent:"


def _load_demo_payload() -> dict[str, object]:
    return {
        "message": "Arcori cached demo",
        "revision": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }


def get_cached_demo_payload() -> dict[str, object]:
    payload = read_cache.get_or_load(
        _EXAMPLE_CACHE_KEY,
        ttl_seconds=example_cache_ttl_seconds(),
        loader=_load_demo_payload,
    )
    return {
        **payload,
        "cache_enabled": read_cache.is_enabled(),
    }


def record_from_body(body: dict[str, Any]) -> dict[str, Any]:
    user_id = str(body.get("user_id", "")).strip()
    payload = body.get("payload")
    if not isinstance(payload, dict):
        payload = {}
    if not user_id:
        raise ValueError("user_id required")

    revision = int(payload.get("revision", 0) or 0)

    with session_scope() as session:
        row = example_repository.insert_record(
            session,
            user_id=user_id,
            revision=revision,
            payload=payload,
        )

    read_cache.delete(f"{_RECENT_CACHE_PREFIX}{user_id}")
    create_for_user(
        user_id,
        source="example_module",
        notification_type=NOTIFICATION_TYPE_INBOX,
        title="Example record saved",
        body=f"Revision {revision} was stored for your account.",
        category="record",
        subtype="example_record_saved",
        msg_id="example_module_record_saved",
        data={"record_id": str(row.id), "revision": revision},
    )
    return {
        "id": str(row.id),
        "user_id": row.user_id,
        "revision": row.revision,
    }


def record_from_request() -> dict[str, Any]:
    return record_from_body(parse_json_body())


def recent_for_user(user_id: str, *, limit: int = 20) -> list[dict[str, Any]]:
    cache_key = f"{_RECENT_CACHE_PREFIX}{user_id}"

    def _load() -> list[dict[str, Any]]:
        with session_scope() as session:
            rows = example_repository.list_for_user(session, user_id, limit=limit)
        return [
            {
                "revision": row.revision,
                "payload": row.payload,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]

    return read_cache.get_or_load(
        cache_key,
        ttl_seconds=example_cache_ttl_seconds(),
        loader=_load,
    )
