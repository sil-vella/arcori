# WebSocket system — plain English guide

This chart shows how **arcori** real-time messaging works across Flutter, FastAPI, and Dart.

## What is it?

WebSockets keep a **live connection** open (unlike REST where each request is separate). Both backends speak the **same JSON message format** as HTTP: `{ok, data}` or `{ok, error}`.

On Flutter, **`WsConnectionManager`** owns shared sockets. It reconnects on auth change, on `token_expired`, and on **unexpected drops** (exponential backoff). Inbound frames demux by channel prefix into module notifiers — see [state-ws-routing-flow](../../flutter/state/state-ws-routing-flow.html). Drop reconnect and room re-subscribe are **Flutter-only** — [state-ws-reconnect-flow](../../flutter/state/state-ws-reconnect-flow.html).

## Three tiers (same idea as HTTP)

| URL | Who | Login |
|-----|-----|-------|
| `/ws/public` | Anyone | Connected immediately |
| `/ws/authuser` | Logged-in app user | First message: send JWT |
| `/ws/service` | Internal servers | First message: send service key |

## Try it locally

1. Start debug compose (loads `.env.local`):

   ```bash
   cd docker
   docker compose --env-file ../.env.local -f docker-compose.debug.yml up -d
   ```

2. Flutter: `wfrun` → launch → login if prompted → drawer **WS Demo**
3. **Connect both WS** → **Subscribe room** → **Ping** / **Echo**
4. Restart `Arcori_dart` — client should backoff-reconnect and re-subscribe

Or use curl REST for token, then a WS client:

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/public/auth/dev-login \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"test"}' | jq -r '.data.access_token')

# Use wscat or Flutter demo with ws://127.0.0.1:8080/ws/authuser
# First frame:
# {"type":"auth","channel":"system","payload":{"access_token":"<TOKEN>"}}
# Then:
# {"type":"ping","channel":"system"}
```

## Demo channels

- **`system`** — `ping` → `pong` (health check for WS)
- **`demo/echo`** — send `{text}` → get `{echo: text}` back
- **`demo/room`** — `subscribe` / `unsubscribe` / `event` — room join/leave + broadcast (both backends). Client must re-subscribe after reconnect.

## Production

- **Dart :8080** — primary game / realtime (`CADDY_GAME_DOMAIN` → `wss://game.example/ws/authuser`)
- **FastAPI :8000** — app API + WS (`CADDY_DOMAIN` → `wss://api.example/ws/authuser`)
- FastAPI Gunicorn uses **UvicornWorker** (`uvicorn.workers.UvicornWorker`) for WebSocket — not gevent

More: [WS_SYSTEM.md](../../../03_Base/WS_SYSTEM.md), [PRODUCTION_SYSTEM.md](../../../03_Base/PRODUCTION_SYSTEM.md)
