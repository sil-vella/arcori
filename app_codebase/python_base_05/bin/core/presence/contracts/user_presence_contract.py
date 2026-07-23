"""Module-facing presence read API — online user → session mapping.

Feature modules call :meth:`UserPresenceReader.sessions_for_user` (or
:meth:`UserPresenceReader.is_online`) without importing ``redis`` or knowing
whether the backing store is Redis or in-memory.

Access the runtime singleton via ``from core.presence import user_presence_reader``
or ``from core.state.state_registry import user_presence`` (same instance).

Do **not** use this for WS frame delivery — that uses the per-worker transport
index (:class:`~core.state.contracts.user_connection_reader_contract.UserConnectionReader`).
"""

from __future__ import annotations

from typing import Protocol

from core.presence.presence_types import UserSession


class UserPresenceReader(Protocol):
    """Cross-worker online mapping: user_id → active authuser WS sessions."""

    def is_online(self, user_id: str) -> bool:
        """True when the user has at least one active authuser WS session (any worker)."""
        ...

    def session_count(self, user_id: str) -> int:
        """Number of active authuser WS sessions for [user_id] (any worker)."""
        ...

    def sessions_for_user(self, user_id: str) -> list[UserSession]:
        """Session metadata for [user_id] — session_id, worker_id, tier, timestamps."""
        ...
