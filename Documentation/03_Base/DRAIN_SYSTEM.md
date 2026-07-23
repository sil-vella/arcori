# Arcori — Drain system (app layer)

Operator guide for **application drain** before stopping or updating Docker containers. Edge drain (nginx / `.draining` flag) lives in the **VPS-specific repo** — coordinate both layers in production.

Related: [PRODUCTION_SYSTEM.md](PRODUCTION_SYSTEM.md) · [PYTHON_DART_BACKEND.md](PYTHON_DART_BACKEND.md) · [SECURITY_SYSTEM.md](SECURITY_SYSTEM.md) · active plan [drain-maintenance-pipeline.md](../01_Active_Plans/drain-maintenance-pipeline.md)

## Architecture

```text
ops_drain.py ──X-Service-Key──► FastAPI /service/ops/*
                                    │
                                    ├─ Postgres ops_runtime.drain_mode (shared workers)
                                    └─ HTTP ► Dart /service/ops/drain-mode|drain-status
                                                  │
                                                  └─ reject new WS; block demo/room subscribe
```

| Layer | Role |
|-------|------|
| FastAPI | Persist `drain_mode`, HTTP 503 gate, aggregate readiness |
| Dart | In-process drain flag, WS reject, room counts |
| Edge (VPS repo) | Block new public traffic at nginx — not configured in this repo |

**Abort policy:** If poll times out, run `ops_drain.py exit` and deactivate edge drain. **Do not stop containers.**

## APIs

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/service/ops/enter-drain` | `X-Service-Key` | Enable drain (FastAPI + notify Dart) |
| POST | `/service/ops/exit-drain` | `X-Service-Key` | Disable drain |
| GET | `/service/ops/drain-status` | `X-Service-Key` | Aggregate readiness |
| POST | `/service/ops/drain-mode` | `X-Service-Key` | Dart only — `{"enabled": true\|false}` |
| GET | `/service/ops/drain-status` | `X-Service-Key` | Dart only — room/connection counts |

**Allowlisted FastAPI paths during drain:** `/health`, `/service/health`, `/service/ops/*`, `/service/auth/validate`. All other HTTP and `/ws/*` return **503** `ops/drain_mode`.

Dart WS reject code: `server_maintenance`. Template matchmaking stand-in: `demo/room` `subscribe` is blocked under drain; in-room `event` / `unsubscribe` continue.

## Operator CLI

```bash
set -a && source .env.local && set +a   # or .env.prod
export OPS_DRAIN_BASE_URL=http://127.0.0.1:8000

python3 app_codebase/python_base_05/tools/ops_drain.py enter
python3 app_codebase/python_base_05/tools/ops_drain.py poll --max-wait 120 --interval 5
python3 app_codebase/python_base_05/tools/ops_drain.py status
python3 app_codebase/python_base_05/tools/ops_drain.py exit
```

Or via `wfrun`:

```bash
wfrun → automation/local/ops_drain.sh enter
```

Env: `OPS_DRAIN_BASE_URL`, `SERVICE_KEY`. Compose sets `DART_SERVICE_URL=http://Arcori_dart:8080` on the API container.

**Ready when:** `drain_mode`, `active_rooms == 0`, all `in_flight` counters 0, Dart reachable, and `--stable-polls` consecutive clears. Open WS connections may remain (lobby).

## Maintenance flow (app layer)

1. Edge activate (VPS repo) + `ops_drain.py enter`
2. `ops_drain.py poll` until `ready: true`
3. Stop / pull / up containers on VPS
4. `ops_drain.py exit` + edge deactivate

## Fork extensions

- Register in-flight counters: `register_in_flight_counter("jobs", lambda: n)` in Python.
- Extra HTTP allowlist prefixes: append to `EXTRA_DRAIN_ALLOW_PREFIXES` in `drain_guard.py`.
- Real matchmaking: gate create/join/start events the same way as `demo/room` subscribe.

## Edge drain reminder (VPS / nginx repo)

1. Activate/deactivate `.draining` (or equivalent) and reload nginx.
2. **503** new user traffic; **pass through** `GET /health` and `/service/*`.
3. On poll timeout: deactivate edge + app exit-drain; do not stop containers.
