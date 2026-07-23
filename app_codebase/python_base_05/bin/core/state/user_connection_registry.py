"""Maps authenticated user ids to active WebSocket connection ids (this worker only).

Implements :class:`~core.state.contracts.user_connection_reader_contract.UserConnectionReader`.
Feature modules should use :class:`~core.presence.contracts.user_presence_contract.UserPresenceReader`
for online queries instead.
"""

from __future__ import annotations


class UserConnectionRegistry:
    def __init__(self) -> None:
        self._user_to_connections: dict[str, set[str]] = {}
        self._connection_to_user: dict[str, str] = {}

    def clear(self) -> None:
        self._user_to_connections.clear()
        self._connection_to_user.clear()

    def register(self, user_id: str, connection_id: str) -> None:
        uid = user_id.strip()
        if not uid:
            return
        self._connection_to_user[connection_id] = uid
        self._user_to_connections.setdefault(uid, set()).add(connection_id)

    def unregister(self, connection_id: str) -> None:
        user_id = self._connection_to_user.pop(connection_id, None)
        if user_id is None:
            return
        connections = self._user_to_connections.get(user_id)
        if connections is None:
            return
        connections.discard(connection_id)
        if not connections:
            self._user_to_connections.pop(user_id, None)

    def connection_ids_for_user(self, user_id: str) -> set[str]:
        uid = user_id.strip()
        if not uid:
            return set()
        return set(self._user_to_connections.get(uid, set()))

    def user_id_for_connection(self, connection_id: str) -> str | None:
        return self._connection_to_user.get(connection_id)
