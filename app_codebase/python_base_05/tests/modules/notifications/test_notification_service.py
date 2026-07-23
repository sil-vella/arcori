"""Notification service unit tests (serialization helpers)."""

from __future__ import annotations

import uuid

import pytest

from core.errors.app_error import AppError
from modules.notifications.notification_service import (
    _GLOBAL_ID_PREFIX,
    _serialize_global_row,
    _serialize_user_row,
    mark_global_read_for_user,
)


class _FakeGlobalRow:
    id = uuid.UUID("65f0a1b2-c3d4-e5f6-0718-290200000001")
    source = "global_broadcast"
    type = "instant"
    category = "system"
    subtype = "welcome"
    msg_id = "global_welcome_v1"
    title = "Welcome"
    body = "Hello"
    data = {}
    responses = []
    created_at = __import__("datetime").datetime(
        2026, 6, 30, 12, 0, tzinfo=__import__("datetime").timezone.utc
    )


class _FakeUserRow:
    id = uuid.UUID("11111111-1111-1111-1111-111111111111")
    source = "example_module"
    type = "inbox"
    category = "record"
    subtype = "example_record_saved"
    msg_id = "example_module_record_saved"
    title = "Saved"
    body = "Record stored"
    data = {"revision": 1}
    responses = []
    read_at = None
    created_at = __import__("datetime").datetime(
        2026, 6, 30, 12, 0, tzinfo=__import__("datetime").timezone.utc
    )


def test_serialize_user_row_shape() -> None:
    payload = _serialize_user_row(_FakeUserRow())
    assert payload["origin"] == "user"
    assert payload["type"] == "inbox"
    assert payload["id"] == str(_FakeUserRow.id)


def test_serialize_global_row_shape() -> None:
    payload = _serialize_global_row(_FakeGlobalRow(), user_read=False)
    assert payload["origin"] == "global"
    assert payload["user_read"] is False
    assert payload["id"].startswith(_GLOBAL_ID_PREFIX)


def test_mark_global_read_invalid_user_raises() -> None:
    with pytest.raises(AppError):
        mark_global_read_for_user("not-a-uuid", ["glob_abc"])
