"""Bootstrap reset for tier-2 transport state."""

from __future__ import annotations

from core.presence.presence_factory import build_presence_store
from core.presence.user_presence_service import UserPresenceService
from core.state.connection_registry import ConnectionRegistry
from core.state.room.broadcast_hub import BroadcastHub
from core.state.room.room_registry import RoomRegistry
from core.state.user_connection_registry import UserConnectionRegistry
from core.ws.inbox_broadcaster import InboxBroadcaster

connection_registry = ConnectionRegistry()
user_connection_registry = UserConnectionRegistry()
room_registry = RoomRegistry()
room_broadcaster = BroadcastHub(connections=connection_registry, membership=room_registry)
inbox_broadcaster = InboxBroadcaster(
    connections=connection_registry,
    user_connections=user_connection_registry,
)
user_presence = UserPresenceService(
    local_connections=user_connection_registry,
    store=build_presence_store(),
)


def reset_state_registry() -> None:
    connection_registry.clear()
    user_presence.clear()
    room_registry.clear()
