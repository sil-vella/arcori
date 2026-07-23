"""Tier 2 — room membership (connection_id ↔ room_id)."""

from __future__ import annotations

from core.state.contracts.room_membership_contract import RoomMembershipContract


class RoomRegistry(RoomMembershipContract):
    def __init__(self) -> None:
        self._room_connections: dict[str, set[str]] = {}
        self._connection_rooms: dict[str, set[str]] = {}
        self._connection_users: dict[str, str | None] = {}

    def subscribe(self, room_id: str, connection_id: str, *, user_id: str | None = None) -> None:
        self._room_connections.setdefault(room_id, set()).add(connection_id)
        self._connection_rooms.setdefault(connection_id, set()).add(room_id)
        self._connection_users[connection_id] = user_id

    def unsubscribe(self, room_id: str, connection_id: str) -> None:
        room_set = self._room_connections.get(room_id)
        if room_set is not None:
            room_set.discard(connection_id)
            if not room_set:
                self._room_connections.pop(room_id, None)
        conn_set = self._connection_rooms.get(connection_id)
        if conn_set is not None:
            conn_set.discard(room_id)
            if not conn_set:
                self._connection_rooms.pop(connection_id, None)
                self._connection_users.pop(connection_id, None)

    def connection_ids(self, room_id: str) -> set[str]:
        return set(self._room_connections.get(room_id, set()))

    def user_id_for(self, connection_id: str) -> str | None:
        return self._connection_users.get(connection_id)

    def on_connection_closed(self, connection_id: str) -> None:
        rooms = self._connection_rooms.pop(connection_id, None)
        self._connection_users.pop(connection_id, None)
        if not rooms:
            return
        for room_id in rooms:
            room_set = self._room_connections.get(room_id)
            if room_set is not None:
                room_set.discard(connection_id)
                if not room_set:
                    self._room_connections.pop(room_id, None)

    def clear(self) -> None:
        self._room_connections.clear()
        self._connection_rooms.clear()
        self._connection_users.clear()
