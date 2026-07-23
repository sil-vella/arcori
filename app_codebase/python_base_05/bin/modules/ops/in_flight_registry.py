"""Named in-flight counters for drain readiness (forks register hooks)."""

from __future__ import annotations

from collections.abc import Callable

_counters: dict[str, Callable[[], int]] = {}


def register_in_flight_counter(name: str, getter: Callable[[], int]) -> None:
    """Register a named counter used in drain-status ``in_flight``."""
    key = name.strip()
    if not key:
        raise ValueError("in_flight counter name must be non-empty")
    _counters[key] = getter


def reset_in_flight_registry() -> None:
    _counters.clear()


def snapshot_in_flight() -> dict[str, int]:
    return {name: int(getter()) for name, getter in sorted(_counters.items())}
