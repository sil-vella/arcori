# arcori — WebSocket system

Technical guide for the **complete base-template WebSocket stack** across FastAPI, Dart, and Flutter. For HTTP/service coordination, see [PYTHON_DART_BACKEND.md](PYTHON_DART_BACKEND.md). For auth tiers, see [SECURITY_SYSTEM.md](SECURITY_SYSTEM.md). For error envelopes and WS policy, see [ERROR_SYSTEM.md](ERROR_SYSTEM.md). For Flutter inbound routing to notifiers, see [Flutter/STATE_SYSTEM.md](Flutter/STATE_SYSTEM.md).

**Chart + plain English guide:** [ws-system-flow — diagram](../02_FlowCharts/charts/base/ws-system-flow.html) · [guide](../02_FlowCharts/charts/base/ws-system-flow.guide.html) · Flutter reconnect: [state-ws-reconnect-flow](../02_FlowCharts/charts/flutter/state/state-ws-reconnect-flow.html)

Regenerate charts: `python3 automation/backend/build_nav_and_charts.py` or `wfcharts` from project root.

## Overview

Shared JSON WebSocket protocol on **FastAPI** (`:8000`) and **Dart** (`:8080`), plus **Flutter** transport (`core/ws`) and demo modules. Phase 1 (this template) is **infrastructure + demo channels** — no game room or match backend logic yet.

| Stack | Role |
|-------|------|
| **FastAPI** | App-wide REST + WS; service-tier authority |
| **Dart** | Game-facing REST + **primary realtime** WS |
| **Flutter** | Shared `WsConnectionManager`, prefix router, module notifiers |

## Endpoints

| Tier | Path | Auth handshake |
|------|------|----------------|
| public | `/ws/public` | Auto-connected — server sends `connected` |
| authuser | `/ws/authuser` | First frame: `{type: "auth", channel: "system", payload: {access_token}}` |
| service | `/ws/service` | First frame: `{type: "auth", channel: "system", payload: {service_key}}` |

Same three-tier model as HTTP. Service key travels in the **first WS frame**, not as an HTTP header on the upgrade request.

## Message shape

**Client → server:** `{type, channel, payload?}`

**Server → client:** same envelope as HTTP — `{"ok": true, "data": …}` or `{"ok": false, "error": {"code", "message"}}`

Both backends accept either a bare client object or a full envelope with `ok: true` and `data` containing the client object (`parse_incoming` / `parseIncoming`).

## Connection loop

Both stacks use the same pattern in `ws_dispatcher`:

1. Create `WsConnectionContext` for the tier.
2. **Public:** mark authenticated, send `connected`.
3. **Authuser / service:** require first message `type == "auth"`; otherwise `unauthorized` and close.
4. Route subsequent messages by **`channel`** through the channel registry.
5. Invoke handler; send result or error frame. Fatal codes close the connection.

## Demo channels

Registered on all three tiers in `modules/ws/demo_ws_app.*`:

| Channel | Client `type` | Server response |
|---------|----------------|-----------------|
| `system` | `ping` | `pong` + UTC timestamp |
| `demo/echo` | `event` + `{text}` | `{echo: text}` |
| `demo/room` | `subscribe` / `unsubscribe` / `event` | Room join/leave + broadcast (see below) |

### demo/room (both backends)

Core provides `RoomRegistry` + `BroadcastHub`; `modules/ws/demo_ws_service.*` wires the channel.

| Client `type` | Payload | Behavior |
|---------------|---------|----------|
| `subscribe` | `{room_id?}` (default `demo`) | Ack `subscribed`; broadcast `member_joined` to peers |
| `unsubscribe` | `{room_id?}` | Ack `unsubscribed`; broadcast `member_left` |
| `event` | `{room_id?, text}` | Broadcast `room_message` to room |

Server push uses the same `{ok, data}` envelope with `{type, channel, payload}` in `data`.

### example_module channel (Dart authuser tier)

See [EXAMPLE_MODULE.md](EXAMPLE_MODULE.md).

| Channel | Client `type` | Server behavior |
|---------|---------------|-----------------|
| `example/state` | `event` | Bump in-memory revision; optional FastAPI record |

## Code layout

| Stack | Path |
|-------|------|
| Python core | `app_codebase/python_base_05/bin/core/ws/` |
| Python demo | `app_codebase/python_base_05/bin/modules/ws/` |
| Dart core | `app_codebase/dart_bkend_base_02/bin/core/ws/` |
| Dart demo | `app_codebase/dart_bkend_base_02/bin/modules/ws/` |
| Dart example_module | `app_codebase/dart_bkend_base_02/bin/modules/example_module/` |
| Flutter transport | `app_codebase/flutter_base_06/lib/core/ws/` |
| Flutter WS demo | `app_codebase/flutter_base_06/lib/modules/ws_demo/` |
| Flutter example_module | `app_codebase/flutter_base_06/lib/modules/example_module/` |
| Python example_module | `app_codebase/python_base_05/bin/modules/example_module/` |
| Flutter state routing | `app_codebase/flutter_base_06/lib/core/state/` + module `register_*_state.dart` |

### Channel registry (backends)

Mirrors the HTTP route registry. Modules register handlers per tier at startup via `registerApplicationWsChannels()`:

```python
# Python — modules/ws/demo_ws_app.py
channels.authuser_channel("system", handle_system)
```

```dart
// Dart — modules/ws/demo_ws_app.dart
channels.authuserChannel('system', handleSystem);
```

Lookup key: `"{tier}:{channel}"` (e.g. `authuser:demo/echo`).

### Flutter client (reconnect is client-side only)

| File | Role |
|------|------|
| `core/ws/ws_client.dart` | Connect, auth handshake, `messages`, `connectionClosed` on unexpected drop |
| `core/ws/ws_connection_manager.dart` | Shared endpoints, backoff reconnect, auth-driven reconnect |
| `core/ws/ws_reconnect_policy.dart` | Exponential backoff (1s → 30s cap) |
| `core/ws/ws_channel_router.dart` | Prefix-based inbound demux |
| `core/state/app_state_registry.dart` | `runWsReconnectHooks()` after each (re)connect |
| `modules/ws_demo/` | Demo screen + room re-subscribe hook |
| `modules/*/register_*_state.dart` | `onWsReady` + optional `onWsReconnect` |

**Reconnect (Flutter only):** backends do not reconnect. On drop, `WsConnectionManager` backoff-reconnects and runs `AppStateSink.onWsReconnect` so modules re-send subscribe frames. Chart: [state-ws-reconnect-flow](../02_FlowCharts/charts/flutter/state/state-ws-reconnect-flow.html).

Screens do **not** create `WsClient` directly. Use `wsConnectionManagerProvider`. Inbound frames route to module notifiers via `buildWsChannelRouter(ref)` — see [Flutter/STATE_SYSTEM.md](Flutter/STATE_SYSTEM.md).

## Try it locally

```bash
cd docker
docker compose --env-file ../.env.local -f docker-compose.debug.yml up -d
```

Flutter: `wfrun` → `automation/frontend/launch_chrome.sh` → drawer **WS Demo** (login if prompted) → **Connect both WS** → **Subscribe room** → restart backend to see client reconnect in log.

Or REST token + manual WS client:

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/public/auth/dev-login \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"test"}' | jq -r '.data.access_token')

# ws://127.0.0.1:8080/ws/authuser
# {"type":"auth","channel":"system","payload":{"access_token":"<TOKEN>"}}
# {"type":"ping","channel":"system"}
```

## Production

- **FastAPI Gunicorn:** `GUNICORN_WORKER_CLASS=uvicorn.workers.UvicornWorker` (default in `gunicorn.conf.py`) — required for WebSocket; not gevent.
- **Caddy:** WebSocket upgrade on `/ws/*`, long read timeout (e.g. 3600s); `CADDY_DOMAIN` (API) and `CADDY_GAME_DOMAIN` (Dart).
- **Dart :8080** — primary game / realtime (`wss://game.example/ws/authuser`).
- **FastAPI :8000** — app API + WS (`wss://api.example/ws/authuser`).

See [PRODUCTION_SYSTEM.md](PRODUCTION_SYSTEM.md) for compose, health checks, and tuning.

## Tests

| Stack | File |
|-------|------|
| Python | `app_codebase/python_base_05/test/test_ws_auth_ping.py` |
| Dart | `app_codebase/dart_bkend_base_02/test/ws_auth_ping_test.dart`, `test/example_module_ws_test.dart` |
| Flutter router | `app_codebase/flutter_base_06/test/core/ws/ws_channel_router_test.dart` |

## State ownership

See [EXAMPLE_MODULE.md](EXAMPLE_MODULE.md), [DART_STATE_SYSTEM.md](DART_STATE_SYSTEM.md), [PYTHON_STATE_SYSTEM.md](PYTHON_STATE_SYSTEM.md).

Authuser WS connect/disconnect updates local transport mapping and shared presence — see [PRESENCE_SYSTEM.md](PRESENCE_SYSTEM.md).

## Not in this template (product work)

- Game rules, MatchStore, `match/*` channels
- Match-scoped WS credentials
- Redis pub/sub for multi-instance WS fan-out

## Related charts

- [ws-system-flow](../02_FlowCharts/charts/base/ws-system-flow.html) — Flutter, FastAPI, Dart WS tiers
- [state-ws-routing-flow](../02_FlowCharts/charts/flutter/state/state-ws-routing-flow.html) — Flutter inbound message → notifier
- [security-auth-flow](../02_FlowCharts/charts/base/security-auth-flow.html) — JWT + service key
- [error-handling-flow](../02_FlowCharts/charts/base/error-handling-flow.html) — shared error envelope
