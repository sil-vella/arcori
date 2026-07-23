"""Tests for example_module demo notifications."""

from __future__ import annotations

from unittest.mock import patch

from modules.example_module.example_notifications import create_demo_notifications_for_user


def test_create_demo_notifications_creates_navigate_and_reply() -> None:
    with patch(
        "modules.example_module.example_notifications.create_for_user",
    ) as create:
        create.side_effect = ["nav-id", "reply-id"]
        result = create_demo_notifications_for_user("user-1")

    assert result == {
        "navigate_message_id": "nav-id",
        "reply_message_id": "reply-id",
    }
    assert create.call_count == 2

    navigate_call = create.call_args_list[0].kwargs
    reply_call = create.call_args_list[1].kwargs

    assert navigate_call["notification_type"] == "instant"
    assert navigate_call["data"]["response"]["type"] == "navigate"
    assert navigate_call["category"] == "demo"
    assert navigate_call["subtype"] == "example_navigate_demo"

    assert reply_call["data"]["response"]["type"] == "reply"
    assert reply_call["category"] == "demo"
    assert reply_call["subtype"] == "example_reply_demo"
    assert len(reply_call["data"]["response"]["options"]) == 2
