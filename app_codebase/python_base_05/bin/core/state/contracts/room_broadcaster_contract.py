"""Fan-out server push to all connections in a room."""

from __future__ import annotations

from typing import Protocol


class RoomBroadcasterContract(Protocol):
    def broadcast_to_room(
        self,
        room_id: str,
        *,
        channel: str,
        msg_type: str,
        payload: dict,
        exclude_connection_id: str | None = None,
    ) -> None: ...
