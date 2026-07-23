"""Ops drain service — enter/exit drain and readiness aggregate."""

from __future__ import annotations

import logging
from typing import Any

from core.http.dart_service_client import fetch_dart_drain_status, set_dart_drain_mode
from modules.ops.in_flight_registry import snapshot_in_flight
from modules.ops.ops_state import is_drain_mode, set_drain_mode

logger = logging.getLogger(__name__)


def enter_drain() -> dict[str, Any]:
    set_drain_mode(True)
    dart_ok = set_dart_drain_mode(True)
    if not dart_ok:
        logger.warning("enter_drain: FastAPI drain on; Dart notify failed")
    return {
        "drain_mode": True,
        "dart_notified": dart_ok,
    }


def exit_drain() -> dict[str, Any]:
    set_drain_mode(False)
    dart_ok = set_dart_drain_mode(False)
    if not dart_ok:
        logger.warning("exit_drain: FastAPI drain off; Dart notify failed")
    return {
        "drain_mode": False,
        "dart_notified": dart_ok,
    }


def drain_status() -> dict[str, Any]:
    drain = is_drain_mode()
    in_flight = snapshot_in_flight()
    dart_reachable, dart_data = fetch_dart_drain_status()

    active_rooms = int(dart_data.get("active_rooms", 0)) if dart_reachable else 0
    room_count = int(dart_data.get("room_count", active_rooms)) if dart_reachable else 0
    dart_connections = (
        int(dart_data.get("dart_connections", 0)) if dart_reachable else 0
    )

    rooms_clear = dart_reachable and active_rooms == 0
    in_flight_clear = all(v == 0 for v in in_flight.values())
    ready = bool(drain and rooms_clear and in_flight_clear and dart_reachable)

    return {
        "drain_mode": drain,
        "active_rooms": active_rooms,
        "in_flight": in_flight,
        "dart_connections": dart_connections,
        "room_count": room_count,
        "checks": {
            "rooms_clear": rooms_clear,
            "in_flight_clear": in_flight_clear,
        },
        "ready": ready,
        "dart_reachable": dart_reachable,
    }
