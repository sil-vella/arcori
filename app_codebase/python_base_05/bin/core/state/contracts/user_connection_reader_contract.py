"""Per-worker transport index: user_id ↔ connection_id (local sockets only).

Core WS delivery (e.g. :class:`~core.ws.inbox_broadcaster.InboxBroadcaster`) uses
this to find open connections on **this Gunicorn worker**. It does **not** reflect
online status on other workers.

Feature modules should **not** import this for “is user online?” — use
:class:`~core.presence.contracts.user_presence_contract.UserPresenceReader` instead.
To nudge a user over WS, prefer core helpers (notifications → ``inbox_changed``)
rather than reading connection ids directly.
"""

from __future__ import annotations

from typing import Protocol


class UserConnectionReader(Protocol):
    """Local-only user ↔ connection mapping for outbound WS on this worker."""

    def connection_ids_for_user(self, user_id: str) -> set[str]:
        """Open authuser connection ids held by this worker for [user_id]."""
        ...

    def user_id_for_connection(self, connection_id: str) -> str | None:
        """Resolve [connection_id] to user_id, or None if unknown on this worker."""
        ...
