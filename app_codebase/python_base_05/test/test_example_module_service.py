"""Tests for example_module record helpers."""

from __future__ import annotations

from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest

from modules.example_module.example_service import get_cached_demo_payload, record_from_body, recent_for_user


def test_record_from_body_requires_user_id():
    with pytest.raises(ValueError, match="user_id"):
        record_from_body({})


def test_record_from_body_persists_and_invalidates_cache():
    row = MagicMock()
    row.id = uuid4()
    row.user_id = "u1"
    row.revision = 2

    with patch("modules.example_module.example_service.session_scope") as scope, patch(
        "modules.example_module.example_service.example_repository.insert_record",
        return_value=row,
    ) as insert, patch("modules.example_module.example_service.read_cache") as cache, patch(
        "modules.example_module.example_service.create_for_user",
    ) as create_notification:
        scope.return_value.__enter__.return_value = MagicMock()
        result = record_from_body(
            {
                "user_id": "u1",
                "payload": {"revision": 2, "message": "hello"},
            }
        )

    insert.assert_called_once()
    create_notification.assert_called_once()
    cache.delete.assert_called_once_with("example_module:recent:u1")
    assert result["user_id"] == "u1"
    assert result["revision"] == 2


def test_recent_for_user_uses_read_cache():
    with patch("modules.example_module.example_service.read_cache") as cache:
        cache.get_or_load.return_value = [{"revision": 1}]
        items = recent_for_user("u1")

    assert items == [{"revision": 1}]
    cache.get_or_load.assert_called_once()


def test_get_cached_demo_payload():
    with patch("modules.example_module.example_service.read_cache") as cache:
        cache.get_or_load.return_value = {"message": "demo", "revision": 1}
        cache.is_enabled.return_value = False
        payload = get_cached_demo_payload()

    assert payload["message"] == "demo"
    assert payload["cache_enabled"] is False
