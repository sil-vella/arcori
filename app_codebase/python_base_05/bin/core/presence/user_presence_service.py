"""Facade: local WS transport index + shared presence store."""

from __future__ import annotations

from datetime import datetime, timezone

from core.presence.contracts.presence_store_contract import PresenceStoreContract
from core.presence.presence_config import worker_id
from core.presence.presence_types import UserSession
from core.state.user_connection_registry import UserConnectionRegistry


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class UserPresenceService:
    def __init__(
        self,
        *,
        local_connections: UserConnectionRegistry,
        store: PresenceStoreContract,
    ) -> None:
        self._local = local_connections
        self._store = store
        self._worker_id = worker_id()

    def register_authuser_session(self, user_id: str, session_id: str) -> None:
        uid = user_id.strip()
        sid = session_id.strip()
        if not uid or not sid:
            return
        now = _now_iso()
        self._local.register(uid, sid)
        self._store.register_session(
            session_id=sid,
            user_id=uid,
            worker_id=self._worker_id,
            tier="authuser",
            connected_at=now,
            last_seen_at=now,
        )

    def unregister_session(self, session_id: str) -> None:
        self._local.unregister(session_id)
        self._store.unregister_session(session_id)

    def touch_session(self, session_id: str) -> None:
        self._store.touch_session(session_id, last_seen_at=_now_iso())

    def is_online(self, user_id: str) -> bool:
        return self.session_count(user_id) > 0

    def session_count(self, user_id: str) -> int:
        return len(self.sessions_for_user(user_id))

    def sessions_for_user(self, user_id: str) -> list[UserSession]:
        return self._store.sessions_for_user(user_id)

    def clear(self) -> None:
        self._local.clear()
        self._store.clear()
