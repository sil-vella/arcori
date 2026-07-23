"""Push inbox_changed events to all WS sessions for a user."""

from __future__ import annotations

from core.state.connection_registry import ConnectionRegistry
from core.state.user_connection_registry import UserConnectionRegistry
from core.ws.response.ws_response import encode_ok

_INBOX_CHANNEL = "notifications/inbox"
_INBOX_EVENT = "inbox_changed"


class InboxBroadcaster:
    def __init__(
        self,
        *,
        connections: ConnectionRegistry,
        user_connections: UserConnectionRegistry,
    ) -> None:
        self._connections = connections
        self._user_connections = user_connections

    def notify_inbox_changed(self, user_id: str) -> None:
        uid = user_id.strip()
        if not uid:
            return
        frame = encode_ok(
            {
                "type": "event",
                "channel": _INBOX_CHANNEL,
                "payload": {"event": _INBOX_EVENT},
            }
        )
        for connection_id in self._user_connections.connection_ids_for_user(uid):
            self._connections.send(connection_id, frame)
