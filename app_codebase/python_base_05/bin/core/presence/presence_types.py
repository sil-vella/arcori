"""User WebSocket session metadata for presence tracking."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class UserSession:
    """One active authuser WebSocket session (from :class:`UserPresenceReader`)."""

    session_id: str  # Same as connection_id on the owning worker
    user_id: str
    worker_id: str  # Gunicorn worker that accepted the socket (hostname:pid)
    tier: str  # v1: always "authuser"
    connected_at: str  # ISO-8601 UTC
    last_seen_at: str  # ISO-8601 UTC; refreshed on each inbound WS frame
