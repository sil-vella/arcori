# arcori — Python backend state system

Infrastructure for **durable state and caching** in `python_base_05`. Domain tables live in **modules** — see [EXAMPLE_MODULE.md](EXAMPLE_MODULE.md).

**Chart:** [backend-state-split](../02_FlowCharts/charts/base/backend-state-split.html)

Related: [WS_SYSTEM.md](WS_SYSTEM.md) · [DART_STATE_SYSTEM.md](DART_STATE_SYSTEM.md)

## Tiers

| Tier | Component | Lifetime |
|------|-----------|----------|
| 1 — Session | `request_context`, JWT guards | Per HTTP request |
| 2 — Transport | HTTP/WS guards, `ConnectionRegistry`, room broadcast | Request / connection |
| 3b — Durable domain | Module repositories + Postgres | Permanent |
| 4 — Ephemeral | Handler locals | Function scope |

No hot gameplay store on FastAPI — Dart owns realtime state.

## Core layout

```
python_base_05/bin/core/state/
  session_scope.py         commit/rollback wrapper — use for all DB writes
  connection_registry.py   WS outbound send per connection_id
  user_connection_registry.py  local user_id ↔ connection_id (transport; UserConnectionReader)
  room/                    RoomRegistry, BroadcastHub (mirrors Dart)
  state_registry.py        reset on transport rebuild; user_presence singleton

python_base_05/bin/core/presence/
  user_presence_service.py syncs transport + shared store (UserPresenceReader)
  user_presence_reader in __init__.py — module singleton (lazy, like read_cache)
```

See [PRESENCE_SYSTEM.md](PRESENCE_SYSTEM.md) for the two-layer mapping (transport vs presence), contracts, env vars, and HTTP API.

## Database access

```python
from core.state.session_scope import session_scope

with session_scope() as session:
    example_repository.insert_record(session, ...)
```

Migration head: run `python3 bin/migrate.py` when schema changes; `/health` compares `alembic_version` to the Alembic script head automatically.

## Reference module

[`modules/example_module/`](../../app_codebase/python_base_05/bin/modules/example_module/):

| Route | Tier | Purpose |
|-------|------|---------|
| `GET /public/example/cached` | public | Redis read-through demo |
| `POST /service/example_module/record` | service | Dart durable write |
| `GET /authuser/example_module/recent` | authuser | Recent records (cached) |

Merged former `modules/example/` cache demo into this module.

## Add durable state to a new module

1. Model under `models/` + Alembic migration.
2. `*_repository.py` + `*_service.py` + `*_app.py`.
3. Wire in `module_registry.py`.
4. Use `session_scope()`; invalidate cache keys on writes.

## Tests

`PYTHONPATH=bin python3 -m pytest test/` — includes `test_example_module_service.py`, `test_session_scope.py`.

## Future

- `users` table linked to JWT `sub`
- Background aggregation jobs
