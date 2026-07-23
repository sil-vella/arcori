# wfsecrets — Environment files and secrets

A plain-language guide to **where secrets live** and **how to use them** with Docker Compose, `wfrun`, and Flutter.

## Backend env (compose)

| File | When | Used by |
|------|------|---------|
| **`.env.local`** | Development on your machine | `docker-compose.debug.yml` (`env_file`) |
| **`.env.prod`** | VPS / production | `docker-compose.yml` (`env_file`) |

**Never commit** `.env.local` or `.env.prod`. They are gitignored.

**Do commit** the samples:

- [`.env.local.sample`](../../.env.local.sample) — copy to `.env.local`
- [`.env.prod.sample`](../../.env.prod.sample) — copy to `.env.prod` on the server

## Flutter env (`dart-define`)

| File | When | Used by |
|------|------|---------|
| **`.env.dart.defines.local`** | Local Flutter runs | `wfrun` → `automation/frontend/*` (local) |
| **`.env.dart.defines.prod`** | Prod / VPS Flutter builds | `wfrun` → `automation/frontend/*` (prod) |

Samples: [`.env.dart.defines.local.sample`](../../.env.dart.defines.local.sample), [`.env.dart.defines.prod.sample`](../../.env.dart.defines.prod.sample).

Keys include `ARCORI_API_REST_URL`, `ARCORI_API_WS_URL`, `ARCORI_DART_WS_URL`, `FLUTTER_WEB_PORT`, `FLUTTER_WEB_HOSTNAME`, and Firebase GA4 keys (`FIREBASE_SWITCH`, `FIREBASE_APP_ENVIRONMENT`, `FIREBASE_ANDROID_*`, `FIREBASE_IOS_*`). See [wfrun.md](wfrun.md) and [FIREBASE_IMPLEMENTATION.md](../03_Base/FIREBASE_IMPLEMENTATION.md).

## Setup (first time)

```bash
cd /path/to/app_dev_template_flutter_fastapi_dart_postgress
cp .env.local.sample .env.local
cp .env.dart.defines.local.sample .env.dart.defines.local
# Edit .env.local — keep dev placeholders or set your own dev secrets
```

On the VPS:

```bash
cp .env.prod.sample .env.prod
cp .env.dart.defines.prod.sample .env.dart.defines.prod
# Fill every REPLACE_WITH_* value with strong random strings
```

Generate random secrets:

```bash
openssl rand -hex 32
```

## What each secret does

| Variable | One-line purpose |
|----------|------------------|
| `ARCORI_ENV` | `local` vs `production` — production turns on strict checks |
| `JWT_SECRET` | Signs **access** tokens (clients send these as `Bearer …`) |
| `JWT_REFRESH_SECRET` | Signs **refresh** tokens (get a new access token) |
| `SERVICE_KEY` | Shared password for `/service/*` routes (FastAPI ↔ Dart) |
| `DATABASE_URL` | FastAPI runtime (app role when RBAC on) — see [POSTGRES_RBAC.md](../03_Base/POSTGRES_RBAC.md) |
| `MIGRATION_DATABASE_URL` | Alembic / migrations / notification seed (owner) |
| `READONLY_DATABASE_URL` | Adminer and read-only ops |
| `PG_RBAC_ENABLED` | `0` local default; `1` production |
| `POSTGRES_APP_USER` / `POSTGRES_APP_PASSWORD` | App role credentials |
| `POSTGRES_READONLY_USER` / `POSTGRES_READONLY_PASSWORD` | Read-only role credentials |
| `PORT` | FastAPI listen port in compose (local default `8000`; Dart uses `8080` via compose override) |
| `POSTGRES_PASSWORD` | Owner / bootstrap password (migrations) |
| `ARCORI_ALLOW_DEV_LOGIN` | `true` only on local — enables test login without Google |
| `CORS_ALLOWED_ORIGINS` | Which web origins may call the API from a browser |
| `CADDY_DOMAIN` | API hostname for automatic HTTPS via Caddy (production) |
| `CADDY_GAME_DOMAIN` | Dart / game hostname for Caddy (production) |
| `ARCORI_PRESENCE_ENABLED` | `true` → Redis-backed user online tracking on FastAPI authuser WS |
| `ARCORI_PRESENCE_SESSION_TTL_SECONDS` | Session TTL (default 90s; refreshed on WS frames) |
| `ARCORI_PRESENCE_KEY_PREFIX` | Redis key prefix for presence (default `Arcori:presence:`) |
| `REDIS_HOST` / `REDIS_PORT` | Redis for rate limits, refresh sessions, read-cache, and/or presence (compose: `Arcori_redis`) |
| `ARCORI_RATE_LIMIT_ENABLED` | `true` → Redis fixed-window HTTP rate limits (global + stricter auth) |
| `ARCORI_REFRESH_SESSION_KEY_PREFIX` | Redis key prefix for current refresh `jti` per user |
| `FIREBASE_SWITCH` | Master on/off for Firebase GA4 init and events (Flutter) |
| `FIREBASE_APP_ENVIRONMENT` | `development` or `production` — tagged on GA4 events |
| `FIREBASE_ANDROID_*` / `FIREBASE_IOS_*` | Firebase project keys for native mobile (Flutter dart-define) |

## Test login locally (until Google Sign-In ships)

With `ARCORI_ALLOW_DEV_LOGIN=true` in `.env.local` and debug compose running:

```bash
cd docker
docker compose --env-file ../.env.local -f docker-compose.debug.yml up -d
curl -s -X POST http://127.0.0.1:8000/public/auth/dev-login \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"test-user-1"}' | jq .
```

Use the returned `access_token`:

```bash
curl -s http://127.0.0.1:8000/authuser/user/profile \
  -H "Authorization: Bearer <access_token>" | jq .
```

## Rules

- Do **not** paste secrets in chat, email, or tickets.
- Do **not** use prod secrets on your laptop.
- Do **not** set `ARCORI_ALLOW_DEV_LOGIN=true` on the VPS.
- Do **not** set `APP_DEBUG=1` when `ARCORI_ENV=production`.

## More detail

- Technical security doc: [SECURITY_SYSTEM.md](../03_Base/SECURITY_SYSTEM.md)
- Production runtime: [PRODUCTION_SYSTEM.md](../03_Base/PRODUCTION_SYSTEM.md)
- Env runner: [wfrun.md](wfrun.md)
