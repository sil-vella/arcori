"""Tests for notification subtype registry."""

from __future__ import annotations

import pytest

from core.errors.app_error import AppError
from core.notifications.register_builtin_subtypes import register_builtin_notification_subtypes
from core.notifications.response_config import validate_data_response
from core.notifications.subtype_registry import (
    lookup_subtype_spec,
    require_subtype_spec,
    reset_notification_subtypes,
)


@pytest.fixture(autouse=True)
def _reset_registry() -> None:
    reset_notification_subtypes()
    register_builtin_notification_subtypes()


def test_require_subtype_spec_known() -> None:
    spec = require_subtype_spec(
        source="example_module",
        category="demo",
        subtype="example_navigate_demo",
    )
    assert "home" in spec.allowed_screens


def test_require_subtype_spec_unknown_raises() -> None:
    with pytest.raises(AppError) as exc:
        require_subtype_spec(
            source="example_module",
            category="missing",
            subtype="missing",
        )
    assert exc.value.code == "notifications/unknown_subtype"


def test_validate_data_response_enforces_allowed_screens() -> None:
    with pytest.raises(AppError) as exc:
        validate_data_response(
            {
                "response": {
                    "type": "navigate",
                    "buttons": [{"label": "Bad", "screen": "ws_demo"}],
                }
            },
            source="example_module",
            category="demo",
            subtype="example_navigate_demo",
        )
    assert exc.value.code == "notifications/invalid_response_config"


def test_lookup_returns_none_for_legacy_rows() -> None:
    assert (
        lookup_subtype_spec(
            source="example_module",
            category=None,
            subtype=None,
        )
        is None
    )
