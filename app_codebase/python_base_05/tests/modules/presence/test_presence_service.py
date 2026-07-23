"""Presence HTTP route tests."""

from __future__ import annotations

import uuid
from unittest.mock import patch

import pytest

from core.errors.app_error import AppError
from modules.presence.presence_service import parse_user_ids, presence_for_users


def test_parse_user_ids_comma_separated() -> None:
    uid = str(uuid.uuid4())
    other = str(uuid.uuid4())
    result = parse_user_ids(f"{uid},{other}")
    assert result == [uid, other]


def test_parse_user_ids_rejects_empty() -> None:
    with pytest.raises(AppError) as exc:
        parse_user_ids("")
    assert exc.value.code == "presence/invalid_request"


def test_presence_for_users_shape() -> None:
    uid = str(uuid.uuid4())
    with patch("modules.presence.presence_service.user_presence_reader") as mock_reader:
        mock_reader.session_count.return_value = 2
        payload = presence_for_users([uid])
    assert payload["users"][uid]["online"] is True
    assert payload["users"][uid]["session_count"] == 2
