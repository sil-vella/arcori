# arcori — Python and Dart backend coordination

Technical guide for how **python_base_05** (FastAPI) and **dart_bkend_base_02** (Shelf) relate in production: role split, the **service key** (`SERVICE_KEY`), and the shared **WebSocket** stack. For JWT tiers and secrets setup, see [SECURITY_SYSTEM.md](SECURITY_SYSTEM.md) and [wfsecrets.md](../00_System_Wide/wfsecrets.md). For Gunicorn, Redis, and health checks on FastAPI, see [PRODUCTION_SYSTEM.md](PRODUCTION_SYSTEM.md). For error codes on auth failures, see [ERROR_SYSTEM.md](ERROR_SYSTEM.md).

## Role split

Both backends implement the **same three-tier HTTP model** (public / authuser / service) and the **same WebSocket protocol**. They are not duplicates of each other — each has a distinct job on the VPS.

| Backend | Process | Port (compose) | Primary job |
|---------|---------|----------------|-------------|
| **FastAPI** (`python_base_05`) | `Arcori_api` | `8000` | REST API for the mobile/web app; app-wide WebSocket; **authoritative** service-tier endpoints Dart calls internally |
| **Dart** (`dart_bkend_base_02`) | `Arcori_dart` | `8080` | Game-facing REST + **primary realtime** WebSocket (rooms, match traffic) |

```text
Flutter (arcori)
  │
  ├─ Caddy (TLS) ──► FastAPI :8000     REST /authuser/*, /public/auth/*
  │                  └── /ws/*        app notifications, shared demo channels
  │
  └─ Caddy (TLS) ──► Dart :8080       REST + /ws/authuser   game / match realtime

Dart container (internal Docker network only)
  └──► FastAPI :8000  /service/*        X-Service-Key — never exposed on public Caddy
```

**FastAPI** is the app API and internal service hub. **Dart** is the low-latency game server clients connect to for realtime play.

Dart reaches FastAPI on the **service tier** when it needs shared app logic (token validation today; catalog, match coordination, etc. later).

Both stacks share **`JWT_SECRET`**, **`JWT_REFRESH_SECRET`**, and **`SERVICE_KEY`** from env (`.env.local` / `.env.prod`). JWTs issued by FastAPI are valid on Dart and vice versa because both use HS256 with the same secrets.

## Service key mechanism

The service key is a **shared secret** between Dart and FastAPI. It proves the caller is an internal backend process, not an end user. It is **not** a JWT and must never be sent to mobile clients.

### HTTP (`/service/*`)

| Item | Detail |
|------|--------|
| Env var | `SERVICE_KEY` |
| Client header | `X-Service-Key: <value>` |
| Guard | `service_guard` middleware on both stacks |
| Verification | `verify_service_key_or_raise` / `verifyServiceKeyOrThrow` — constant-time compare via `secrets_equal` |
| Failure | HTTP **403** `forbidden` / `Invalid service key` |
| Route registration | Register path **without** `/service` prefix; framework mounts under `/service` |

Example — Dart (or ops) validates a user access token against FastAPI:

```bash
curl -s -X POST http://Arcori_api:8000/service/auth/validate \
  -H 'Content-Type: application/json' \
  -H 'X-Service-Key: <SERVICE_KEY>' \
  -d '{"access_token":"<access_token>"}' | jq .
```

Success → `{"ok":true,"data":{"user_id":"…","claims":{…},"valid":true}}`. Wrong key → **403**. Bad or expired JWT → **401** `invalid_token`.

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/service/auth/validate` | Verify a user access JWT (Dart → FastAPI) |
| `GET` | `/service/health` | Internal health probe with service key |
| `POST` | `/service/ops/enter-drain` | Enable drain (FastAPI → Dart notify) |
| `POST` | `/service/ops/exit-drain` | Disable drain |
| `GET` | `/service/ops/drain-status` | Aggregate readiness (FastAPI polls Dart) |
| `POST` | `/service/ops/drain-mode` | Dart only — set drain flag |
| `GET` | `/service/ops/drain-status` | Dart only — room/connection counts |

FastAPI reaches Dart via `DART_SERVICE_URL` (compose: `http://Arcori_dart:8080`) and `SERVICE_KEY`. See [DRAIN_SYSTEM.md](DRAIN_SYSTEM.md).

**Never cache** `/service/auth/validate`, `/service/health`, `/service/ops/*`, or auth POSTs.

In production, **`/service/*` must not appear on public Caddy**. Only containers on the internal Docker network (e.g. `Arcori_dart` → `Arcori_api:8000`) should call these routes.

### WebSocket (`/ws/service`)

On WebSocket tiers, the service key travels in the **first auth frame**, not as an HTTP header (the upgrade request has already completed).

First client message after connecting to `/ws/service`:

```json
{
  "type": "auth",
  "channel": "system",
  "payload": { "service_key": "<SERVICE_KEY>" }
}
```

Server responds with the standard envelope:

```json
{"ok": true, "data": {"type": "connected", "channel": "system"}}
```

On failure the connection is closed after an error frame. The same `verify_service_key_*` helpers used for HTTP also gate WS service auth — one implementation, two transports.

### Fail-closed startup

When `ARCORI_ENV=production`, both apps refuse to start if `SERVICE_KEY` is missing or still a placeholder (`change-me`, `REPLACE_WITH`). Coordinate rotation: update `.env.prod`, redeploy **both** FastAPI and Dart containers with the new key.

## User JWT vs service key

| Credential | Who holds it | HTTP | WebSocket |
|------------|--------------|------|-----------|
| **Access JWT** | Logged-in app user | `Authorization: Bearer …` on `/authuser/*` | First frame on `/ws/authuser`: `payload.access_token` |
| **Service key** | Backend processes only | `X-Service-Key` on `/service/*` | First frame on `/ws/service`: `payload.service_key` |
| **None** | Anyone | `/public/*`, `GET /health` | `/ws/public` — auto-connected |

Dart can validate user JWTs **locally** (`verifyAccess` / same `JWT_SECRET`) or **remotely** via `POST /service/auth/validate` on FastAPI. Use the HTTP validate route when FastAPI should be the single source of truth; use local verify for hot paths on the game server.

## WebSocket implementation

FastAPI and Dart run **parallel WS stacks** with identical wire behavior. Phase 1 (current) is infrastructure plus demo channels — no game room logic yet.

### Endpoints

| URL | Tier | Auth handshake |
|-----|------|----------------|
| `/ws/public` | public | None — server sends `connected` immediately |
| `/ws/authuser` | authuser | First message must be `type: "auth"` with `access_token` |
| `/ws/service` | service | First message must be `type: "auth"` with `service_key` |

### Message shape

Client frames use `{type, channel, payload}`. Server replies use the **same JSON envelope as HTTP**: `{"ok": true, "data": …}` or `{"ok": false, "error": {"code", "message"}}`.

Incoming parse rules (`parse_incoming` / `parseIncoming`):

1. Accept a bare client object `{type, channel, payload?}`.
2. Or accept a full envelope with `ok: true` and `data` containing that object.

Handler return values are wrapped in `encode_ok` / `encodeWsOk`. `AppError` instances map to error frames; some codes set `fatal_ws` and close the connection.

### Connection loop

Both stacks use a shared pattern in `ws_dispatcher`:

1. Create `WsConnectionContext` for the tier.
2. **Public:** mark authenticated, send `connected`.
3. **Authuser / service:** require first message `type == "auth"`; otherwise `unauthorized` and close.
4. Route subsequent messages by **`channel`** through `get_channel_handler(tier, channel)`.
5. Invoke handler `(ctx, msg)`; send result or error frame.

### Channel registry

Mirrors the HTTP route registry. Modules register handlers per tier:

```python
# Python — modules/ws/demo_ws_app.py
channels.authuser_channel("system", handle_system)
```

```dart
// Dart — modules/ws/demo_ws_app.dart
channels.authuserChannel('system', handleSystem);
```

Lookup key is `"{tier}:{channel}"` (e.g. `authuser:demo/echo`).

### Demo channels (both backends)

| Channel | Client `type` | Server response |
|---------|-----------------|-----------------|
| `system` | `ping` | `pong` + UTC timestamp |
| `demo/echo` | `event` + `{text}` | `{echo: text}` |
| `demo/room` | `subscribe` / `unsubscribe` | `not_implemented` (stub for future game rooms) |

### Stack-specific mounting

| Stack | WS library | Entry |
|-------|------------|-------|
| **FastAPI** | Starlette WebSocket | `core/ws/ws_app.py` — `@app.websocket("/ws/…")` |
| **Dart** | `shelf_web_socket` | `core/ws/ws_app.dart` — combined HTTP + WS handler |

FastAPI uses **Gunicorn + UvicornWorker** (`GUNICORN_WORKER_CLASS=uvicorn.workers.UvicornWorker`, default in `gunicorn.conf.py`) for WebSocket. Caddy must forward `Upgrade` and `Connection` on `/ws/*` with a long read timeout (e.g. 3600s).

### Flutter client

`flutter_base_06/lib/core/ws/ws_client.dart` connects, sends the auth handshake when `accessToken` or `serviceKey` is provided, and exposes a `messages` stream. The **WS Demo** screen (`modules/ws_demo/`) exercises both FastAPI and Dart endpoints locally.

## Code layout

| Concern | Python (`python_base_05/bin/`) | Dart (`dart_bkend_base_02/bin/`) |
|---------|-------------------------------|----------------------------------|
| Service key verify | `core/auth/verify_service_key.py` | `core/auth/verify_service_key.dart` |
| HTTP service guard | `core/http/middleware/service_guard.py` | `core/http/middleware/service_guard.dart` |
| Auth validate route | `modules/auth/auth_app.py` → `/auth/validate` | `modules/auth/auth_app.dart` → `/auth/validate` |
| WS dispatcher | `core/ws/ws_dispatcher.py` | `core/ws/ws_dispatcher.dart` |
| WS channel registry | `core/ws/service/channel_registry.py` | `core/ws/service/channel_registry.dart` |
| WS mount | `core/ws/ws_app.py` | `core/ws/ws_app.dart` |
| Demo channels | `modules/ws/demo_ws_app.py` | `modules/ws/demo_ws_app.dart` |
| Module wiring | `modules/module_registry.py` | `modules/module_registry.dart` |

## Production checklist

1. **Secrets:** `JWT_SECRET`, `JWT_REFRESH_SECRET`, `SERVICE_KEY` set in `.env.prod` for both `Arcori_api` and `Arcori_dart` (same `env_file` in compose).
2. **Network:** Dart → FastAPI on `http://Arcori_api:8000/service/…` inside `app-network`; no public `/service` on Caddy.
3. **Client URLs:** Point game WS at Dart (`wss://game.example/ws/authuser`); app-wide WS at FastAPI (`wss://api.example/ws/authuser`) if both are exposed.
4. **Health:** `GET /health` (FastAPI public); `GET /service/health` with service key from Dart or ops.

## Local smoke test

```bash
# 1. Tokens from FastAPI (dev login)
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/public/auth/dev-login \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"test"}' | jq -r '.data.access_token')

# 2. Service-tier validate (Dart → FastAPI pattern)
curl -s -X POST http://127.0.0.1:8000/service/auth/validate \
  -H 'Content-Type: application/json' \
  -H 'X-Service-Key: dev-service-key-change-me' \
  -d "{\"access_token\":\"$TOKEN\"}" | jq .

# 3. WebSocket on Dart — first frame after connect to ws://127.0.0.1:8080/ws/authuser:
# {"type":"auth","channel":"system","payload":{"access_token":"<TOKEN>"}}
# Then: {"type":"ping","channel":"system"}
```

Or use Flutter via `wfrun` → `launch_chrome.sh` → **WS Demo** → dev login → **Connect both WS** → ping/echo.

## State ownership

See [EXAMPLE_MODULE.md](EXAMPLE_MODULE.md) for the cross-stack reference module.

| Backend | Hot module state | Durable / cache |
|---------|------------------|-----------------|
| **Dart** | Module-owned store + WS (e.g. `example/state`) | — |
| **FastAPI** | — | `example_module_records`, Redis cache |

Chart: [backend-state-split](../02_FlowCharts/charts/base/backend-state-split.html)

## Next phases

Not in this template yet:

- Match-scoped WS credential for game rooms
- Redis pub/sub for multi-instance WS fan-out
- Game catalog `/service/*` routes beyond example_module record

## Charts

- [Security auth flow — diagram](../02_FlowCharts/charts/base/security-auth-flow.html) · [guide](../02_FlowCharts/charts/base/security-auth-flow.guide.html) — JWT + service key on HTTP
- [WebSocket system flow — diagram](../02_FlowCharts/charts/base/ws-system-flow.html) · [guide](../02_FlowCharts/charts/base/ws-system-flow.guide.html) — Flutter, FastAPI, Dart WS tiers
- [Backend state split — diagram](../02_FlowCharts/charts/base/backend-state-split.html) · [guide](../02_FlowCharts/charts/base/backend-state-split.guide.html) — Dart hot vs Python durable
- [example-module-state-flow](../02_FlowCharts/charts/dart_backend/state/example-module-state-flow.html) · [guide](../02_FlowCharts/charts/dart_backend/state/example-module-state-flow.guide.html)

Rebuild HTML after editing `.mmd` / `.guide.md` sources:

```bash
python3 automation/backend/build_nav_and_charts.py
```

## Incident debugging

```bash
# Auth failures (HTTP + WS)
docker compose -f docker/docker-compose.yml logs Arcori_api 2>&1 \
  | grep -E 'auth_failure|invalid_token|token_expired|invalid_service_key|ws_error'

docker compose -f docker/docker-compose.yml logs Arcori_dart 2>&1 \
  | grep -E 'auth_failure|ws_error'
```

Never log or paste raw JWTs or `SERVICE_KEY` in tickets or chat.
