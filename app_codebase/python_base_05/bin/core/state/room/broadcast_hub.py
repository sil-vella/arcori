"""Tier 2 — broadcast server push to room members."""

from __future__ import annotations

from core.state.connection_registry import ConnectionRegistry
from core.state.contracts.room_broadcaster_contract import RoomBroadcasterContract
from core.state.contracts.room_membership_contract import RoomMembershipContract
from core.ws.response.ws_response import encode_ok


class BroadcastHub(RoomBroadcasterContract):
    def __init__(
        self,
        *,
        connections: ConnectionRegistry,
        membership: RoomMembershipContract,
    ) -> None:
        self._connections = connections
        self._membership = membership

    def broadcast_to_room(
        self,
        room_id: str,
        *,
        channel: str,
        msg_type: str,
        payload: dict,
        exclude_connection_id: str | None = None,
    ) -> None:
        frame = encode_ok({"type": msg_type, "channel": channel, "payload": payload})
        for connection_id in self._membership.connection_ids(room_id):
            if connection_id == exclude_connection_id:
                continue
            self._connections.send(connection_id, frame)
