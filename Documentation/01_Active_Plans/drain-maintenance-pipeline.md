# DR / update push pipeline — graceful drain

**Status**: Completed (app layer)  
**Created**: 2026-07-10  
**Last Updated**: 2026-07-20

## Objective

Implement a **two-layer drain system** (edge + app) so operators can safely block new traffic, finish in-flight realtime work, and stop or update Docker containers without killing active sessions. Behavior mirrors the Dutch app (*DR / update push pipeline (rop01)*) but is adapted to this template's stack: **FastAPI** (`python_base_05`), **Dart** (`dart_bkend_base_02`), and **PostgreSQL**.

**App layer is implemented in this repo.** Edge drain (nginx / `.draining`) remains in the VPS-specific repo — see [DRAIN_SYSTEM.md](../03_Base/DRAIN_SYSTEM.md) final notes.

## Reference

Source runbook: Dutch `app_dev` repo — *DR / update push pipeline (rop01)*. Key concepts to port:

| Dutch concept | WF template equivalent |
|---------------|------------------------|
| nginx edge drain (`rop01_server`) | **Caddy** edge drain (this repo — `docker/caddy/`) |
| Flask `ops_module` | FastAPI `modules/ops/` |
| Dart `dart_bkend_base_01` drain | Dart `dart_bkend_base_02` drain |
| `ops_drain.py` CLI | `app_codebase/python_base_05/tools/ops_drain.py` |
| `DART_BACKEND_SERVICE_KEY` | `SERVICE_KEY` (`X-Service-Key` header) |
| `active_matches`, `store_in_flight` | Extensible readiness hooks (rooms + module in-flight counters) |
| Mongo `main_state.drain_mode` | In-process flag + optional `platform_meta` row for observability |

**Abort policy (same as Dutch):** If poll times out, run app `exit-drain` and edge `--deactivate`. **Do not stop containers.**

---

## Architecture

```text
Client ──► Caddy :443 (API + game domains)     ← edge drain: .draining flag + Caddy matcher
              ├──► FastAPI :8000   REST, /ws/*, /service/ops/*
              └──► Dart :8080      /ws/authuser, internal /service/ops/*

Dart container ──► FastAPI :8000   /service/* (Docker network, X-Service-Key)
```

During drain:

1. **Edge (Caddy)** — `.draining` flag → **503** on new public/authuser/ws user traffic; pass through `/health` and `/service/*`.
2. **FastAPI `ops` module** — `drain_mode`; HTTP **503** (`ops/drain_mode`) on blocked routes; aggregates readiness from Dart + module hooks.
3. **Dart** — rejects new WS connections and room-creation WS events; allows in-game play until rooms end.

Edge-only drain blocks new clients at Caddy but does **not** gracefully drain in-flight rooms — use **both layers** for production maintenance.

---

## Repo split

| Concern | Location |
|---------|----------|
| Caddy drain gate, `.draining` flag, `--activate` / `--deactivate` script | **This repo** — `docker/caddy/`, `automation/prod/` |
| FastAPI/Dart drain mode, ops APIs, `ops_drain.py`, poll / `ready` | **This repo** — `app_codebase/` |
| Docker compose stop / pull / up | VPS + `docker/docker-compose.yml` |
| WireGuard-gated operator access | [vps-wireguard-vpn-automation.md](vps-wireguard-vpn-automation.md) |

Unlike Dutch (nginx lives in `rop01_server`), **edge drain is implemented here** because Caddy config is in-repo.

---

## Combined maintenance flow

```text
Phase 1a — Edge drain
    maintenance_mode.sh --activate
         │
Phase 1b — App drain
    ops_drain.py enter
         │
Phase 2 — Poll
    ops_drain.py poll  →  ready=true
         │
Phase 3 — Stop / update (VPS)
    docker compose stop / pull / up
         │
Phase 4 — Bring back
    ops_drain.py exit  +  maintenance_mode.sh --deactivate
```

---

## Implementation steps

### Phase 0 — Design & error catalog

- [ ] Add `ops` module error codes in `modules/ops/ops_errors.py` — e.g. `ops/drain_mode` (HTTP 503), register in `module_registry`.
- [ ] Define readiness contract: `DrainReadinessSnapshot` with `drain_mode`, `active_rooms`, `dart_connections`, `in_flight` (dict of named counters), `checks`, `ready`, `dart_reachable`.
- [ ] Document WS client event for blocked connections: `server_maintenance` (same as Dutch).
- [ ] Decide drain state storage: in-process singleton (primary) + optional `platform_meta` key `drain_mode` for cross-worker visibility (Gunicorn has multiple workers — **must** use shared store or accept per-worker drift; prefer Redis or `platform_meta` if multi-worker).

### Phase 1 — FastAPI ops module

**Location:** `app_codebase/python_base_05/bin/modules/ops/`

- [ ] `ops_state.py` — `drain_mode: bool`, `app_status` (`online` | `maintenance`); thread-safe get/set.
- [ ] `ops_service.py`:
  - `enter_drain()` — set drain flag; POST Dart `/service/ops/drain-mode` `{"enabled": true}` via internal HTTP client.
  - `exit_drain()` — reverse.
  - `drain_status()` — GET Dart `/service/ops/drain-status`; merge module in-flight hooks; compute `ready`.
- [ ] `ops_app.py` — register service routes:
  - `POST /service/ops/enter-drain`
  - `POST /service/ops/exit-drain`
  - `GET /service/ops/drain-status`
- [ ] **HTTP drain gate middleware** (in `prod_runtime.py` or dedicated `drain_guard.py`):
  - When `drain_mode` and path not in allowlist → raise `AppError(DRAIN_MODE)` → **503**.
  - Allowlist (template baseline):
    - `/health`, `/service/health`, `/service/ops/*`
    - `/service/auth/validate`
    - Future: per-module service paths needed during in-flight work (forks extend via registry).
- [ ] Wire `register_ops_routes` + `register_ops_errors` in `module_registry.py`.
- [ ] Internal Dart client: reuse pattern from `dart_bkend_base_02/bin/core/http/fastapi_service_client.dart` inverted — Python → Dart HTTP client with `SERVICE_KEY`, env `DART_SERVICE_URL` (default `http://Arcori_dart:8080` in compose).

### Phase 2 — Dart ops + drain mode

**Location:** `app_codebase/dart_bkend_base_02/bin/modules/ops/`

- [ ] `ops_state.dart` — `drainMode` flag; reset in `registerApplicationState()`.
- [ ] `ops_service.dart`:
  - `setDrainMode(bool enabled)`
  - `drainStatus()` — counts from `roomRegistry`, `connectionRegistry`; expose `active_rooms` (rooms with active gameplay — template: rooms not in `ended` state; demo rooms count if non-trivial).
- [ ] `ops_app.dart` — service routes:
  - `POST /service/ops/drain-mode`
  - `GET /service/ops/drain-status`
- [ ] **WS drain gate** in `ws_dispatcher.dart` (or early in connection setup):
  - New connections when `drainMode` → close with `server_maintenance` error frame.
  - Block matchmaking-style events when drain on: `create_room`, `join_room`, `join_random_game`, `start_match` (register in channel handlers / example_module as reference).
- [ ] Allow existing in-room WS traffic until room lifecycle ends.
- [ ] Register in `module_registry.dart`.

### Phase 3 — Operator CLI

**Location:** `app_codebase/python_base_05/tools/ops_drain.py`

- [ ] Subcommands: `enter`, `exit`, `status`, `poll`.
- [ ] Env: `OPS_DRAIN_BASE_URL` (public API URL, e.g. `https://api.example.com`), `SERVICE_KEY`.
- [ ] `poll` flags: `--max-wait`, `--interval`, `--stable-polls` (default 2 consecutive clear polls).
- [ ] **Ready when:**
  - `drain_mode == true`
  - `active_rooms == 0` (or module-defined active sessions)
  - All `in_flight.* == 0` (template starts empty; forks register hooks)
  - Two consecutive clear polls
- [ ] `ready` does **not** require zero connections — post-game lobby WS may remain.
- [ ] On timeout: print abort instructions (`exit-drain`, edge `--deactivate`, do not stop containers).
- [ ] Optional: `wfrun` wrapper script in `automation/prod/ops_drain.sh`.

### Phase 4 — Edge drain (Caddy)

**Location:** `docker/caddy/`, `automation/prod/`

- [ ] `.draining` flag file on VPS app root (e.g. `/opt/apps/arcori/.draining`).
- [ ] Caddy config: when flag exists, return **503** for:
  - `/ws`, `/authuser/*`, `/public/*` (except allowlisted health paths)
  - SPA/static if served via Caddy
  - Pass through: `GET /health`, `/service/*` (401 without key at app, not blocked at edge)
- [ ] `automation/prod/maintenance_mode.sh`:
  - `--activate` — touch `.draining`, `caddy reload` (or restart `Arcori_caddy`)
  - `--deactivate` — remove flag, reload
  - `--status` — report flag state
- [ ] Document manual VPS equivalent and verification curls (mirror Dutch verification table).
- [ ] Update [PRODUCTION_SYSTEM.md](../03_Base/PRODUCTION_SYSTEM.md) with edge drain section.

### Phase 5 — Tests

- [ ] FastAPI: unit tests for allowlist middleware, enter/exit drain, status aggregation (mock Dart client).
- [ ] Dart: `drain_mode` blocks new WS; existing room messages still flow; ops endpoints return expected counts.
- [ ] Integration (local, no Caddy): `ops_drain.py enter` → `poll` → `exit` against debug compose.
- [ ] Document local dev test block (skip Phase 1a; app drain only) in plan footer / PRODUCTION_SYSTEM.

### Phase 6 — Documentation & operator runbook

- [ ] Add `Documentation/03_Base/DRAIN_SYSTEM.md` — full operator runbook (phases 1–4, verification, risks).
- [ ] Cross-link from [PRODUCTION_SYSTEM.md](../03_Base/PRODUCTION_SYSTEM.md), [SECURITY_SYSTEM.md](../03_Base/SECURITY_SYSTEM.md) (`/service/ops/*` tier).
- [ ] Update [PYTHON_DART_BACKEND.md](../03_Base/PYTHON_DART_BACKEND.md) with ops coordination.
- [ ] Mark this plan **Completed** when all phases done.

---

## API reference (target)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/service/ops/enter-drain` | `X-Service-Key` | Enable drain (FastAPI + Dart) |
| POST | `/service/ops/exit-drain` | `X-Service-Key` | Disable drain |
| GET | `/service/ops/drain-status` | `X-Service-Key` | Readiness aggregate (FastAPI) |
| POST | `/service/ops/drain-mode` | `X-Service-Key` | Dart only — `{"enabled": true\|false}` |
| GET | `/service/ops/drain-status` | `X-Service-Key` | Dart only — room/connection counts |

**`GET /service/ops/drain-status` response shape (FastAPI aggregate):**

```json
{
  "drain_mode": true,
  "active_rooms": 0,
  "in_flight": {},
  "dart_connections": 1,
  "room_count": 1,
  "checks": { "rooms_clear": true, "in_flight_clear": true },
  "ready": true,
  "dart_reachable": true
}
```

Dart WS event when blocked: `server_maintenance`.

---

## Before running `ops_drain.py`

From a machine that can reach production (VPN when [vps-wireguard-vpn-automation.md](vps-wireguard-vpn-automation.md) is live):

```bash
cd <repo-root>
set -a && source .env.prod && set +a
export OPS_DRAIN_BASE_URL=https://<CADDY_DOMAIN>
```

`SERVICE_KEY` must match VPS `.env.prod`. Optional: confirm `curl -sS "$OPS_DRAIN_BASE_URL/health"` → 200.

---

## Phase 3 — Stop or update (VPS)

Only after `ready: true`. Not automated from app code.

```bash
cd /opt/apps/arcori/docker
docker compose --env-file ../.env.prod -f docker-compose.yml stop Arcori_dart
docker compose --env-file ../.env.prod -f docker-compose.yml pull
docker compose --env-file ../.env.prod -f docker-compose.yml up -d
curl -sS http://127.0.0.1:8000/health
```

Drain-stop (no deploy): stop `Arcori_dart` and `Arcori_api`; keep Postgres running.

---

## Risks

| Risk | Mitigation |
|------|------------|
| Edge only, no app drain | In-flight rooms not tracked; use both layers |
| Multi-worker drain flag drift | Shared Redis or `platform_meta`; document if single-worker dev |
| Hard stop kills active room | Poll `active_rooms == 0` before Phase 3 |
| `ready` with open WS | Expected; connections ≠ active rooms |
| Fork-specific in-flight work (IAP, jobs) | Register hooks in `ops_service`; poll `in_flight` |

---

## Local dev test (no Caddy edge)

```bash
set -a && source .env.local && set +a
export OPS_DRAIN_BASE_URL=http://127.0.0.1:8000

python3 app_codebase/python_base_05/tools/ops_drain.py enter
python3 app_codebase/python_base_05/tools/ops_drain.py poll --max-wait 120 --interval 5
python3 app_codebase/python_base_05/tools/ops_drain.py exit
```

---

## Current progress

App layer complete:

- FastAPI `modules/ops/` + `ops_runtime` migration + HTTP drain gate
- Dart `modules/ops/` + WS reject + `demo/room` subscribe block
- `tools/ops_drain.py` + `automation/local/ops_drain.sh`
- [DRAIN_SYSTEM.md](../03_Base/DRAIN_SYSTEM.md)

Edge (nginx) not in this repo.

## Next steps

1. Wire edge drain in the VPS/nginx repo (pass through `/health` and `/service/*`).
2. Run local app-only drain smoke: enter → poll → exit against debug compose.
3. After Alembic migrate, verify `/service/ops/drain-status` on a live stack.

## Files to create / modify

| File | Action |
|------|--------|
| `app_codebase/python_base_05/bin/modules/ops/*` | Create |
| `app_codebase/python_base_05/tools/ops_drain.py` | Create |
| `app_codebase/python_base_05/bin/modules/module_registry.py` | Wire ops |
| `app_codebase/python_base_05/bin/core/utils/prod_runtime.py` | Drain middleware (or new file) |
| `app_codebase/dart_bkend_base_02/bin/modules/ops/*` | Create |
| `app_codebase/dart_bkend_base_02/bin/modules/module_registry.dart` | Wire ops |
| `app_codebase/dart_bkend_base_02/bin/core/ws/ws_dispatcher.dart` | WS drain gate |
| `docker/caddy/Caddyfile` | Edge drain matcher |
| `automation/prod/maintenance_mode.sh` | Edge activate/deactivate |
| `Documentation/03_Base/DRAIN_SYSTEM.md` | Operator runbook |
| `Documentation/03_Base/PRODUCTION_SYSTEM.md` | Cross-link |

## Notes

- Dutch readiness includes `store_in_flight` (Mongo IAP). This template has **no store module** — use `in_flight: {}` and a registration API so forks add counters without changing the CLI.
- Dutch uses `python_base_04` / `dart_bkend_base_01`; all paths above use this repo's `python_base_05` / `dart_bkend_base_02`.
- Service-tier ops endpoints are called via public URL in `ops_drain.py` (through Caddy) with `X-Service-Key` — same pattern as Dutch; ensure Caddy does not block `/service/ops/*` during edge drain.
- Consider exposing drain status on VPN-only admin port later; not required for v1.
