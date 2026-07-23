"""In-process presence store for tests and when Redis is disabled."""

from __future__ import annotations

from core.presence.presence_types import UserSession


class InMemoryPresenceStore:
    def __init__(self) -> None:
        self._sessions: dict[str, UserSession] = {}
        self._user_to_sessions: dict[str, set[str]] = {}

    def is_enabled(self) -> bool:
        return True

    def register_session(
        self,
        *,
        session_id: str,
        user_id: str,
        worker_id: str,
        tier: str,
        connected_at: str,
        last_seen_at: str,
    ) -> None:
        uid = user_id.strip()
        sid = session_id.strip()
        if not uid or not sid:
            return
        session = UserSession(
            session_id=sid,
            user_id=uid,
            worker_id=worker_id,
            tier=tier,
            connected_at=connected_at,
            last_seen_at=last_seen_at,
        )
        self._sessions[sid] = session
        self._user_to_sessions.setdefault(uid, set()).add(sid)

    def unregister_session(self, session_id: str) -> None:
        sid = session_id.strip()
        session = self._sessions.pop(sid, None)
        if session is None:
            return
        user_sessions = self._user_to_sessions.get(session.user_id)
        if user_sessions is None:
            return
        user_sessions.discard(sid)
        if not user_sessions:
            self._user_to_sessions.pop(session.user_id, None)

    def touch_session(self, session_id: str, *, last_seen_at: str) -> None:
        sid = session_id.strip()
        session = self._sessions.get(sid)
        if session is None:
            return
        self._sessions[sid] = UserSession(
            session_id=session.session_id,
            user_id=session.user_id,
            worker_id=session.worker_id,
            tier=session.tier,
            connected_at=session.connected_at,
            last_seen_at=last_seen_at,
        )

    def sessions_for_user(self, user_id: str) -> list[UserSession]:
        uid = user_id.strip()
        if not uid:
            return []
        session_ids = self._user_to_sessions.get(uid, set())
        return [self._sessions[sid] for sid in session_ids if sid in self._sessions]

    def clear(self) -> None:
        self._sessions.clear()
        self._user_to_sessions.clear()
