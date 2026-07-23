"""Public presence API for feature modules."""

from __future__ import annotations

from core.presence.contracts.user_presence_contract import UserPresenceReader
from core.presence.presence_types import UserSession

__all__ = [
    "UserPresenceReader",
    "UserSession",
    "user_presence_reader",
]


def __getattr__(name: str) -> UserPresenceReader:
    if name == "user_presence_reader":
        from core.state.state_registry import user_presence

        globals()["user_presence_reader"] = user_presence
        return user_presence
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
