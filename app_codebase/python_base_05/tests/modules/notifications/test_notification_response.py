"""Notification response dispatch tests."""

from __future__ import annotations

import uuid
from unittest.mock import MagicMock, patch

import pytest

from core.errors.app_error import AppError
from core.notifications.reply_registry import (
    dispatch_reply,
    register_reply_handler,
    reset_reply_registry,
)
from modules.notifications.notification_service import handle_response


@pytest.fixture(autouse=True)
def _reset_registry() -> None:
    reset_reply_registry()


def test_dispatch_reply_invokes_registered_handler() -> None:
    calls: list[str] = []

    def handler(*, user_id: str, message: dict, option_key: str, **_) -> dict:
        calls.append(option_key)
        return {"success": True, "data": {"status": option_key}}

    register_reply_handler("example_module", handler)
    result = dispatch_reply(
        source="example_module",
        user_id="user-1",
        message={"msg_id": "example_invite_v1"},
        option_key="accept",
    )
    assert result["success"] is True
    assert calls == ["accept"]


def test_dispatch_reply_missing_handler_raises() -> None:
    with pytest.raises(AppError) as exc:
        dispatch_reply(
            source="missing",
            user_id="user-1",
            message={},
            option_key="accept",
        )
    assert exc.value.code == "notifications/handler_not_found"


@patch("modules.notifications.notification_service.session_scope")
def test_handle_response_rejects_non_reply_type(mock_scope: MagicMock) -> None:
    user_id = str(uuid.uuid4())
    message_id = uuid.uuid4()
    row = MagicMock()
    row.id = message_id
    row.source = "example_module"
    row.type = "instant"
    row.subtype = None
    row.msg_id = "test"
    row.title = "Title"
    row.body = "Body"
    row.data = {
        "response": {
            "type": "navigate",
            "buttons": [{"label": "Go", "screen": "home"}],
        }
    }
    row.responses = []
    row.read_at = None
    row.created_at = __import__("datetime").datetime.now(__import__("datetime").timezone.utc)

    session = MagicMock()
    mock_scope.return_value.__enter__.return_value = session

    with patch(
        "modules.notifications.notification_service.repo.get_user_notification",
        return_value=row,
    ):
        with pytest.raises(AppError) as exc:
            handle_response(
                user_id,
                message_id=str(message_id),
                option_key="accept",
            )
    assert exc.value.code == "notifications/not_reply_type"
