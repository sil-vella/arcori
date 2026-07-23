"""Internal presence store contract (Redis or in-memory)."""

from __future__ import annotations

from typing import Protocol

from core.presence.presence_types import UserSession


class PresenceStoreContract(Protocol):
    def is_enabled(self) -> bool: ...

    def register_session(
        self,
        *,
        session_id: str,
        user_id: str,
        worker_id: str,
        tier: str,
        connected_at: str,
        last_seen_at: str,
    ) -> None: ...

    def unregister_session(self, session_id: str) -> None: ...

    def touch_session(self, session_id: str, *, last_seen_at: str) -> None: ...

    def sessions_for_user(self, user_id: str) -> list[UserSession]: ...

    def clear(self) -> None: ...
