# User presence — plain English guide

This chart shows how **arcori** tracks whether a user has an active **FastAPI authuser WebSocket** session, and how feature modules query that state.

## What is it?

When the Flutter app is logged in, `AppWsCoordinator` keeps a connection to `/ws/authuser`. On auth success the API registers **two mappings**:

1. **Transport (local, per worker)** — `user_id` ↔ `connection_id` so this worker can send WS frames (e.g. `inbox_changed`)
2. **Presence (shared)** — `user_id` → session metadata (Redis or in-memory) so **any Gunicorn worker** can answer “is user B online?”

## Two layers — do not mix them up

| Layer | Purpose | Storage | Module API |
|-------|---------|---------|------------|
| **Transport** | Deliver WS frames to open sockets on **this worker** | In-memory `UserConnectionRegistry` | Core only — `UserConnectionReader` |
| **Presence** | Online status, session count, which worker holds the socket | Redis SET + HASH (or in-memory when disabled) | **`UserPresenceReader`** |

Redis does **not** replace local send callbacks — each worker still delivers only to connections it holds.

### In-memory structures (reference)

**Transport** (`user_connection_registry.py`):

- `_user_to_connections[user_id]` → set of `connection_id`
- `_connection_to_user[connection_id]` → `user_id`

**Presence — in-memory** (`in_memory_presence_store.py`):

- `_user_to_sessions[user_id]` → set of `session_id`
- `_sessions[session_id]` → `UserSession` metadata

**Presence — Redis** (`redis_presence_store.py`):

- `Arcori:presence:user:{user_id}` — SET of session ids
- `Arcori:presence:session:{session_id}` — HASH + TTL (default 90s, refreshed on each WS frame)

## Module contract

Feature modules import the **presence reader**, not Redis or the transport registry:

```python
from core.presence import UserPresenceReader, UserSession, user_presence_reader

if user_presence_reader.is_online(target_user_id):
    sessions: list[UserSession] = user_presence_reader.sessions_for_user(target_user_id)
```

Or HTTP batch query:

```http
GET /authuser/presence?user_ids=uuid1,uuid2
Authorization: Bearer …
```

**Do not** use `UserConnectionRegistry` for “is user online?” — it only sees sockets on the current worker.

To push WS traffic, use core delivery paths (e.g. notifications → `inbox_changed`), not raw connection ids.

## Local dev

Debug compose includes `Arcori_redis`. API container sets `REDIS_HOST=Arcori_redis` and `ARCORI_PRESENCE_ENABLED=true`.

Host pytest uses `REDIS_HOST=127.0.0.1` from `.env.local` (port `6379`).

## Limits (v1)

- **FastAPI app WS only** — Dart game WS not tracked
- **InboxBroadcaster** still sends only to **local** connections; cross-worker WS delivery is a follow-up (Redis pub/sub)
- No Postgres presence table

## Related

- [PRESENCE_SYSTEM.md](../../../03_Base/PRESENCE_SYSTEM.md)
- [NOTIFICATION_SYSTEM.md](../../../03_Base/NOTIFICATION_SYSTEM.md)
- [WS_SYSTEM.md](../../../03_Base/WS_SYSTEM.md)
