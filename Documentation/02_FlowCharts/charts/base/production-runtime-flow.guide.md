# Production runtime flow

This chart shows how **python_base_05** runs in Docker or on a production host: Gunicorn with Uvicorn workers, Caddy reverse proxy, PostgreSQL, health checks, and optional in-process read cache.

## Who talks to whom

- **Chat widget / browser** → Caddy (HTTPS) → FastAPI on port **8000** (internal)
- **Internal services** → FastAPI **directly** on `/service/*` routes (not through Caddy if on same Docker network)
- **Developers** → Adminer on **8081** → PostgreSQL (local/debug compose)
- **Docker** pings `GET /health` to know the API container is alive

## Gunicorn and the FastAPI app

Production does **not** use `uvicorn` CLI directly in Docker. Instead:

1. **Gunicorn** starts Uvicorn workers (`GUNICORN_WORKERS`, `GUNICORN_WORKER_CLASS=uvicorn.workers.UvicornWorker`).
2. Each worker loads `asgi:app`, which calls `createHttpHandler()`.
3. `configure_production()` adds slow-request logging and a safe JSON 500 handler.

Tune workers and timeouts in `.env.prod` — see [PRODUCTION_SYSTEM.md](../../../03_Base/PRODUCTION_SYSTEM.md).

## Health endpoints

| URL | Tier | Use |
|-----|------|-----|
| `GET /health` | Public | Load balancers, Docker `HEALTHCHECK`, includes PostgreSQL ping |
| `GET /service/health` | Service | Internal checks with `X-Service-Key` |

Via Caddy (compose main stack):

```bash
curl -s http://localhost/health | jq .
```

Direct (IDE / local uvicorn on port 8000):

```bash
curl -s http://127.0.0.1:8000/health | jq .
```

## Read cache (optional, off in compose)

When `ARCORI_REDIS_READ_CACHE_ENABLED=true` and Redis is reachable, the demo route `GET /example/cached` can use read-through cache. Compose defaults cache **off** (`NoOpReadCache`).

## Docker quick start

```bash
cp .env.prod.sample .env.prod
# Edit secrets and CADDY_DOMAIN, then:
docker compose -f docker/docker-compose.yml up -d --build
docker compose -f docker/docker-compose.yml logs -f Arcori_api
```

Local dev stack (Postgres + Adminer + API with live-mounted source):

```bash
docker compose -f docker/docker-compose.debug.yml up -d
# API: http://127.0.0.1:8000 — edit app_codebase/python_base_05/bin without rebuild
```

Production compose loads `../.env.prod` via `env_file`.

## Logs to watch

```bash
# Slow requests (default ≥ 5000 ms)
docker compose logs Arcori_api 2>&1 | grep slow_request

# Auth issues (never log raw tokens)
docker compose logs Arcori_api 2>&1 | grep auth_failure
```
