# Arcori — Production system (FastAPI)

Operational guide for running **python_base_05** behind Gunicorn (Uvicorn workers) and Caddy on a VPS or in Docker. For authentication and secrets, see [SECURITY_SYSTEM.md](SECURITY_SYSTEM.md) and [wfsecrets.md](../00_System_Wide/wfsecrets.md). For error envelopes and 500 handling, see [ERROR_SYSTEM.md](ERROR_SYSTEM.md). For the visual overview, open the flowchart (see [Charts](#charts) below) or run **`wfcharts`** from the project root.

## Architecture

```text
Browser / Flutter  →  Caddy :443  →  FastAPI :8000  (REST + /ws/*)
Game clients       →  Caddy :443  →  Dart :8080      (REST + /ws/authuser)  [CADDY_GAME_DOMAIN]
Internal services  →  FastAPI :8000  (/service/* — Docker network only)
PostgreSQL         ←  FastAPI (DATABASE_URL)
Adminer :8081      →  PostgreSQL (dev / debug compose only)
```

FastAPI is the **REST, service-tier, and app-wide WebSocket API**. Dart is the **game realtime** server. Caddy terminates TLS; set `CADDY_GAME_DOMAIN` for Dart in production. WebSocket uses native Uvicorn workers (no gevent).

## Code layout

| Piece | Path |
|--------|------|
| ASGI entry | `app_codebase/python_base_05/bin/asgi.py` |
| Gunicorn config | `app_codebase/python_base_05/gunicorn.conf.py` |
| Production hooks | `app_codebase/python_base_05/bin/core/utils/prod_runtime.py` |
| Database config | `app_codebase/python_base_05/bin/core/db/` |
| Error catalog | `app_codebase/python_base_05/bin/core/errors/` — see [ERROR_SYSTEM.md](ERROR_SYSTEM.md) |
| Read-through cache | `app_codebase/python_base_05/bin/core/cache/` (optional; NoOp by default in compose) |
| Example cached route | `GET /example/cached` → `modules/example/example_service.py` |
| Docker image | `app_codebase/python_base_05/Dockerfile` |
| Compose stack | `docker/docker-compose.yml` → `Arcori_api`, `Arcori_dart`, `Arcori_postgres`, `Arcori_adminer`, `Arcori_caddy` |
| Debug compose | `docker/docker-compose.debug.yml` → Postgres, Adminer (`:8081`), API (`:8000`), Dart (`:8080`) |

## Health endpoints

| URL | Tier | Purpose |
|-----|------|---------|
| `GET /health` | public | Docker `HEALTHCHECK`, deploy gates; includes PostgreSQL ping (`db: ok`) |
| `GET /service/health` | service (`X-Service-Key`) | Internal checks from ops or other services |

Register service routes with path **`/health`** only; the framework mounts them under **`/service`**.

## Gunicorn defaults

| Setting | Default | Env override |
|---------|---------|----------------|
| Workers | 2 | `GUNICORN_WORKERS` |
| Worker class | `uvicorn.workers.UvicornWorker` | `GUNICORN_WORKER_CLASS` |
| Timeout | 60s | `GUNICORN_TIMEOUT` |
| Worker recycle | 1000 ± jitter | `GUNICORN_MAX_REQUESTS`, `GUNICORN_MAX_REQUESTS_JITTER` |
| Bind | `0.0.0.0:$PORT` | `PORT` (default **8000** in Docker) |
| `preload_app` | `false` | Safer with multiple workers |

Container command:

```bash
gunicorn -c ../gunicorn.conf.py asgi:app
```

(run with `WORKDIR` = `bin/`)

Access logs go to **stdout** with `duration_us=%(D)s` per request.

## Observability

| Signal | Mechanism |
|--------|-----------|
| Slow requests | `[WARNING] slow_request …` when duration ≥ `SLOW_REQUEST_THRESHOLD_MS` (default **5000**) |
| HTTP 500 | Logs error type + path; full traceback only if `LOG_TRACEBACKS=true` |
| Worker hangs | Gunicorn `WORKER TIMEOUT` in container logs |
| Metrics CIDR | `METRICS_ALLOWED_CIDRS` reserved for a future `/metrics` route |
| Redis cache miss / errors | `redis_read_cache_fail_open` WARNING when cache enabled; handler still returns data via loader |
| Rate limit hit | `rate_limit_hit bucket=…` INFO (stdlib → docker logs) when a bucket is exceeded |
| Rate limit Redis down | `rate_limit_store_fail_open` WARNING; request allowed (fail-open) |

## Optional Redis read-through cache

Debug and **production** compose include **Redis 7** (`Arcori_redis`). Prod uses it for HTTP rate limiting (and optionally presence / read-cache). Read-through cache remains optional and separate.

Feature code can use `read_cache.get_or_load(key, ttl_seconds, loader)` when cache is enabled.

| Variable | Default | Purpose |
|----------|---------|---------|
| `ARCORI_REDIS_READ_CACHE_ENABLED` | `false` | `true` → `RedisReadCache`; `false` → `NoOpReadCache` |
| `ARCORI_PRESENCE_ENABLED` | `false` | `true` → Redis presence store; `false` → in-memory only |
| `ARCORI_PRESENCE_SESSION_TTL_SECONDS` | `90` | Authuser WS session TTL |
| `ARCORI_PRESENCE_KEY_PREFIX` | `Arcori:presence:` | Presence Redis key prefix |
| `REDIS_HOST` | `127.0.0.1` | Host (compose overrides to `Arcori_redis` for API) |
| `REDIS_PORT` | `6379` | Port |
| `ARCORI_REDIS_KEY_PREFIX` | `Arcori:cache:` | Read-cache key prefix |
| `ARCORI_CACHE_EXAMPLE_TTL` | `60` | TTL for `GET /example/cached` only |
| `ARCORI_RATE_LIMIT_ENABLED` | `false` | `true` → Redis fixed-window HTTP rate limits |
| `ARCORI_RATE_LIMIT_KEY_PREFIX` | `Arcori:ratelimit:` | Rate-limit Redis key prefix |
| `ARCORI_RATE_LIMIT_GLOBAL_MAX` / `_WINDOW_S` | `120` / `60` | Per-IP global HTTP ceiling |
| `ARCORI_RATE_LIMIT_AUTH_MAX` / `_WINDOW_S` | `20` / `60` | Per-IP `/public/auth/*` ceiling |
| `ARCORI_RATE_LIMIT_AUTH_IDENTITY_MAX` / `_WINDOW_S` | `10` / `900` | Per-email login/register ceiling |
| `ARCORI_REFRESH_SESSION_KEY_PREFIX` | `Arcori:rt:` | Current refresh `jti` per user (rotation / revoke) |

See [SECURITY_SYSTEM.md](SECURITY_SYSTEM.md) for bucket rules, refresh rotation, and incident greps.

**Do not cache:** `/health`, `/service/health`, and future auth-validation POSTs.

## PostgreSQL

Compose uses `postgres:16`. Runtime connection via `DATABASE_URL` (app role when `PG_RBAC_ENABLED=1`); Alembic and entrypoint migrations use `MIGRATION_DATABASE_URL` (owner). See [POSTGRES_RBAC.md](POSTGRES_RBAC.md) for roles, grants, and `verify_rbac.sh`.

Debug compose (local dev with hot reload):

```bash
docker compose -f docker/docker-compose.debug.yml up -d
# API at http://127.0.0.1:8000 — bin/ and alembic/ are volume-mounted; edit code without rebuild
# Rebuild only when requirements.txt changes: ... up --build Arcori_api
```

Adminer: `http://localhost:8081` (server `Arcori_postgres`, user/password from env).

## Tuning (VPS / compose env)

```env
PORT=8000
GUNICORN_WORKERS=2
GUNICORN_WORKER_CLASS=uvicorn.workers.UvicornWorker
GUNICORN_TIMEOUT=60
SLOW_REQUEST_THRESHOLD_MS=5000
LOG_TRACEBACKS=false
CADDY_DOMAIN=api.your-domain.example
ARCORI_REDIS_READ_CACHE_ENABLED=false
```

## Local development vs production

| Mode | How to run |
|------|------------|
| **Debug (local)** | `docker compose -f docker/docker-compose.debug.yml up -d` — API on `:8000` with mounted source |
| **Production-like** | `docker compose -f docker/docker-compose.yml up --build` |

Dev server uses **uvicorn** directly; production uses Gunicorn + UvicornWorker. Production hooks (`slow_request`, 500 handler) apply whenever `createHttpHandler()` runs.

## Incident debugging (cheat sheet)

From the host or VPS:

```bash
docker compose -f docker/docker-compose.yml logs Arcori_api
docker compose -f docker/docker-compose.yml logs Arcori_caddy
```

Useful greps:

```bash
docker compose -f docker/docker-compose.yml logs Arcori_api 2>&1 | grep -E 'WORKER TIMEOUT|slow_request|internal_error'
docker compose -f docker/docker-compose.yml logs Arcori_api 2>&1 | grep '/health'
```

If health checks fail, confirm `GET /health` returns JSON with `"db":"ok"` inside the API container.

## Charts

This repo documents system flows as **Mermaid** sources under `Documentation/02_FlowCharts/charts/`. HTML is generated by:

```bash
python3 automation/backend/build_nav_and_charts.py
```

Then open the index (or use **`wfcharts`** when CWD is the project root):

- **Production runtime flow:** [diagram](../02_FlowCharts/charts/base/production-runtime-flow.html) · [plain English guide](../02_FlowCharts/charts/base/production-runtime-flow.guide.html)
- **Security auth flow:** [diagram](../02_FlowCharts/charts/base/security-auth-flow.html) · [plain English guide](../02_FlowCharts/charts/base/security-auth-flow.guide.html)
- **Index:** [02_FlowCharts/index.html](../02_FlowCharts/index.html)

After adding or editing `.mmd` files, re-run the build script so nav and HTML stay in sync.

## Not in this template yet

Bring these from a hardened product fork when you need them:

- Versioned image tags + deploy automation with post-deploy health assert
- App `/metrics` endpoint with CIDR restriction
- Product-specific `/service/*` catalog routes for Dart (player catalog read is authuser; see [catalog-hot-reload.md](../01_Active_Plans/catalog-hot-reload.md))

## Drain / maintenance (app layer)

Before stopping or updating containers, use the **app-layer drain** so in-flight rooms can finish. See [DRAIN_SYSTEM.md](DRAIN_SYSTEM.md).

Edge drain (nginx `.draining` flag) is configured in the VPS-specific repo — run it together with `ops_drain.py enter` / `exit`.