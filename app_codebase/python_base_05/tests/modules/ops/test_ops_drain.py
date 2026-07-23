"""Unit tests for drain allowlist and in-flight registry."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

from core.http.middleware.drain_guard import (
    drain_blocked_response,
    path_allowed_during_drain,
)
from modules.ops.in_flight_registry import (
    reset_in_flight_registry,
    snapshot_in_flight,
    register_in_flight_counter,
)
from modules.ops.ops_errors import DRAIN_MODE
from modules.ops.ops_service import drain_status, enter_drain, exit_drain


def test_path_allowed_during_drain() -> None:
    assert path_allowed_during_drain("/health") is True
    assert path_allowed_during_drain("/service/health") is True
    assert path_allowed_during_drain("/service/ops/enter-drain") is True
    assert path_allowed_during_drain("/service/ops/drain-status") is True
    assert path_allowed_during_drain("/service/auth/validate") is True
    assert path_allowed_during_drain("/public/auth/login") is False
    assert path_allowed_during_drain("/ws/authuser") is False
    assert path_allowed_during_drain("/authuser/user/profile") is False


def test_drain_blocked_response_allowlist() -> None:
    request = MagicMock()
    request.method = "GET"
    request.url.path = "/health"
    with patch(
        "core.http.middleware.drain_guard.is_drain_mode",
        return_value=True,
    ):
        assert drain_blocked_response(request) is None


def test_drain_blocked_response_blocks_public() -> None:
    request = MagicMock()
    request.method = "POST"
    request.url.path = "/public/auth/login"
    with patch(
        "core.http.middleware.drain_guard.is_drain_mode",
        return_value=True,
    ):
        response = drain_blocked_response(request)
    assert response is not None
    assert response.status_code == DRAIN_MODE.http_status


def test_drain_blocked_when_not_draining() -> None:
    request = MagicMock()
    request.method = "GET"
    request.url.path = "/public/auth/login"
    with patch(
        "core.http.middleware.drain_guard.is_drain_mode",
        return_value=False,
    ):
        assert drain_blocked_response(request) is None


def test_in_flight_registry_snapshot() -> None:
    reset_in_flight_registry()
    register_in_flight_counter("jobs", lambda: 2)
    assert snapshot_in_flight() == {"jobs": 2}
    reset_in_flight_registry()
    assert snapshot_in_flight() == {}


@patch("modules.ops.ops_service.set_dart_drain_mode", return_value=True)
@patch("modules.ops.ops_service.set_drain_mode", return_value=True)
def test_enter_drain(mock_set: MagicMock, mock_dart: MagicMock) -> None:
    payload = enter_drain()
    assert payload["drain_mode"] is True
    assert payload["dart_notified"] is True
    mock_set.assert_called_once_with(True)
    mock_dart.assert_called_once_with(True)


@patch("modules.ops.ops_service.set_dart_drain_mode", return_value=False)
@patch("modules.ops.ops_service.set_drain_mode", return_value=False)
def test_exit_drain_dart_unreachable(mock_set: MagicMock, mock_dart: MagicMock) -> None:
    payload = exit_drain()
    assert payload["drain_mode"] is False
    assert payload["dart_notified"] is False


@patch(
    "modules.ops.ops_service.fetch_dart_drain_status",
    return_value=(True, {"active_rooms": 0, "room_count": 0, "dart_connections": 1}),
)
@patch("modules.ops.ops_service.snapshot_in_flight", return_value={})
@patch("modules.ops.ops_service.is_drain_mode", return_value=True)
def test_drain_status_ready(
    _drain: MagicMock,
    _inflight: MagicMock,
    _dart: MagicMock,
) -> None:
    status = drain_status()
    assert status["ready"] is True
    assert status["checks"]["rooms_clear"] is True
    assert status["dart_reachable"] is True
    assert status["dart_connections"] == 1


@patch(
    "modules.ops.ops_service.fetch_dart_drain_status",
    return_value=(False, {}),
)
@patch("modules.ops.ops_service.snapshot_in_flight", return_value={})
@patch("modules.ops.ops_service.is_drain_mode", return_value=True)
def test_drain_status_dart_unreachable_not_ready(
    _drain: MagicMock,
    _inflight: MagicMock,
    _dart: MagicMock,
) -> None:
    status = drain_status()
    assert status["ready"] is False
    assert status["dart_reachable"] is False
