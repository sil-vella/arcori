"""Tests for notification response config validation."""

from __future__ import annotations

import pytest

from core.errors.app_error import AppError
from core.notifications.response_config import (
    validate_data_response,
    validate_response_config,
)


def test_validate_navigate_response() -> None:
    config = validate_response_config(
        {
            "type": "navigate",
            "buttons": [
                {"label": "Explore", "screen": "example_module"},
                {"label": "Inbox", "screen": "notifications"},
            ],
        }
    )
    assert config["type"] == "navigate"
    assert len(config["buttons"]) == 2
    assert config["mark_read_on_action"] is True


def test_validate_reply_response() -> None:
    config = validate_response_config(
        {
            "type": "reply",
            "options": [
                {"key": "accept", "label": "Accept"},
                {"key": "decline", "label": "Decline"},
            ],
        }
    )
    assert config["type"] == "reply"
    assert config["options"][0]["key"] == "accept"


def test_validate_navigate_rejects_unknown_screen() -> None:
    with pytest.raises(AppError) as exc:
        validate_response_config(
            {
                "type": "navigate",
                "buttons": [{"label": "Go", "screen": "unknown_screen"}],
            }
        )
    assert exc.value.code == "notifications/invalid_response_config"


def test_validate_navigate_max_buttons() -> None:
    with pytest.raises(AppError):
        validate_response_config(
            {
                "type": "navigate",
                "buttons": [
                    {"label": "One", "screen": "home"},
                    {"label": "Two", "screen": "sample"},
                    {"label": "Three", "screen": "account"},
                    {"label": "Four", "screen": "ws_demo"},
                ],
            }
        )


def test_validate_data_response_merges_normalized_response() -> None:
    data = validate_data_response(
        {
            "revision": 1,
            "response": {
                "type": "reply",
                "options": [{"key": "ok", "label": "OK"}],
            },
        }
    )
    assert data["revision"] == 1
    assert data["response"]["type"] == "reply"
