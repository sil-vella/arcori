# Security and auth flow

This chart shows how **Arcori** checks who is calling the API: app users (JWT), internal services (service key), and public health checks.

## The three route tiers

| Tier | Who uses it | What you send |
|------|-------------|---------------|
| **Public** | Anyone on the internet (via Caddy) | No auth for `/health` and `/media/*`; register/login/refresh on `/public/auth/*` |
| **Auth user** | Authenticated clients | `Authorization: Bearer <access_token>` |
| **Service** | Internal service → FastAPI | `X-Service-Key: <SERVICE_KEY>` |

Full URLs always include the tier prefix, for example `/authuser/user/profile` or `/service/auth/validate`.

## User account endpoints (authuser)

| Path | Purpose |
|------|---------|
| `GET /authuser/user/profile` | Profile (all signed-in users) |
| `POST /authuser/user/profile/avatar` | Upload avatar (full accounts only) |
| `DELETE /authuser/user/profile/avatar` | Remove avatar (full accounts only) |
| `POST /authuser/user/account/convert-guest` | Guest → full in-place upgrade |
| `POST /authuser/user/account/delete` | Delete full account |

See [guest-login-system.md](../../../01_Active_Plans/guest-login-system.md) for Flutter Account screen behaviour and guest vs regular rules.

## Secrets live in env files

Copy [`.env.local.sample`](../../../../.env.local.sample) to `.env.local` for development. On the VPS use `.env.prod` from [`.env.prod.sample`](../../../../.env.prod.sample).

| Variable | Plain English |
|----------|---------------|
| `ARCORI_ENV` | `local` on your machine, `production` on the server |
| `JWT_SECRET` | Signs short-lived **access** tokens |
| `JWT_REFRESH_SECRET` | Signs longer **refresh** tokens |
| `SERVICE_KEY` | Shared password for `/service/*` routes |
| `DATABASE_URL` | PostgreSQL connection string |
| `ARCORI_ALLOW_DEV_LOGIN` | `true` only locally — fake login without real credentials |
| `UPLOAD_ROOT` | Avatar files on disk (Docker volume in compose) |

Flutter client URLs live in [`.env.dart.defines.local.sample`](../../../../.env.dart.defines.local.sample) (not in `.env.local`).

More detail: [wfsecrets.md](../../../00_System_Wide/wfsecrets.md) and [SECURITY_SYSTEM.md](../../../03_Base/SECURITY_SYSTEM.md).

## Example: register and profile (local debug compose)

Start debug compose (loads `.env.local`, API on port **8000**):

```bash
cd docker
docker compose --env-file ../.env.local -f docker-compose.debug.yml up -d
```

```bash
# 1. Register a full account
curl -s -X POST http://127.0.0.1:8000/public/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo","email":"demo@example.com","password":"demo123456","is_guest":false}' | jq .

# 2. Profile — paste access_token from step 1
curl -s http://127.0.0.1:8000/authuser/user/profile \
  -H "Authorization: Bearer <access_token>" | jq .

# 3. Upload avatar (multipart)
curl -s -X POST http://127.0.0.1:8000/authuser/user/profile/avatar \
  -H "Authorization: Bearer <access_token>" \
  -F "avatar=@/path/to/photo.png" | jq .

# 4. Refresh access token
curl -s -X POST http://127.0.0.1:8000/public/auth/refresh \
  -H 'Content-Type: application/json' \
  -d '{"refresh_token":"<refresh_token>"}' | jq .
```

Local-only shortcut:

```bash
curl -s -X POST http://127.0.0.1:8000/public/auth/dev-login \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"test-user-1"}' | jq .
```

## Example: validate a user token (service tier)

```bash
curl -s -X POST http://127.0.0.1:8000/service/auth/validate \
  -H 'Content-Type: application/json' \
  -H 'X-Service-Key: dev-service-key-change-me' \
  -d '{"access_token":"<access_token>"}' | jq .
```

Use the `SERVICE_KEY` value from your `.env.local` (sample default shown above). Wrong service key → **403**. Bad or expired JWT → **401**.

## What is not built yet

Google Sign-In → JWT exchange is planned. Email verification is deferred. HTTP rate limiting (global + `/public/auth/*` + email identity) is implemented — see [SECURITY_SYSTEM.md](../../../03_Base/SECURITY_SYSTEM.md) and [rate-limiting.md](../../../01_Active_Plans/rate-limiting.md).
