# Arcori — Security system

Technical guide for authentication, secrets, and route tiers on **python_base_05** (FastAPI). For secrets setup in plain language, see [wfsecrets.md](../00_System_Wide/wfsecrets.md). For runtime ops, see [PRODUCTION_SYSTEM.md](PRODUCTION_SYSTEM.md). Auth failure JSON codes (`unauthorized`, `token_expired`, …) are catalogued in [ERROR_SYSTEM.md](ERROR_SYSTEM.md). Full user-account flows (guest, convert, profile, avatar) are in [guest-login-system.md](../01_Active_Plans/guest-login-system.md).

## Threat model

| Traffic | Path | Protection |
|---------|------|------------|
| Browser / API client | Caddy → FastAPI public + `/authuser/*` | TLS at Caddy; Bearer JWT on authuser |
| Internal services | internal → FastAPI `/service/*` | `X-Service-Key` + not on public edge |
| Database (FastAPI) | Docker → PostgreSQL | `DATABASE_URL` (app role when RBAC on); see [POSTGRES_RBAC.md](POSTGRES_RBAC.md) |
| Health probes | `GET /health` | Public, no secrets |
| User media | `GET /media/*` | Public read; writes authuser-only |

Assume anything on **public** tier is internet-facing. **Service** tier must never be exposed on public Caddy.

## Route tiers

| Tier | Prefix | Guard |
|------|--------|--------|
| Public | `/`, `/public/*`, `/media/*` | None (media read-only) |
| Auth user | `/authuser/...` | Valid access JWT (HS256) |
| Service | `/service/...` | `X-Service-Key` matches `SERVICE_KEY` |

Register service paths **without** the `/service` prefix (e.g. `/auth/validate` → `POST /service/auth/validate`).

### Public auth endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/public/auth/register` | Create user; `is_guest` optional |
| POST | `/public/auth/login` | Email/password login |
| POST | `/public/auth/dev-login` | Local only (`ARCORI_ALLOW_DEV_LOGIN=true`) |
| POST | `/public/auth/refresh` | Exchange refresh JWT for **new access + new refresh** (rotation) |
| POST | `/public/auth/logout` | Revoke refresh session (body: `refresh_token`); idempotent |
| POST | `/public/auth/verify-email` | Soft verify (`{ token }`); sets `email_verified_at` |

Register and login responses include `user_id` (UUID), `access_token`, `refresh_token`, `token_type`, `is_guest`, and `email_verified`. JWT `sub` is the persisted user UUID from the `users` table.

### Authuser account endpoints

| Method | Path | Guest allowed | Purpose |
|--------|------|---------------|---------|
| GET | `/authuser/user/profile` | Yes | User profile JSON |
| POST | `/authuser/user/profile/avatar` | **No** | Multipart avatar upload |
| DELETE | `/authuser/user/profile/avatar` | **No** | Remove avatar |
| POST | `/authuser/user/account/convert-guest` | Guest only | In-place guest → full account |
| POST | `/authuser/user/account/resend-verification` | Full + unverified | Resend verify email |
| POST | `/authuser/user/account/delete` | **No** | Delete account |

Avatar upload requires `multipart/form-data` with field name `avatar`. Server validates image via Pillow, stores WebP on disk, saves path in `users.avatar_url`.

### Service endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/service/auth/validate` | Internal validate of a user access token |
| POST | `/service/ops/enter-drain` | Enable app drain (FastAPI + Dart) |
| POST | `/service/ops/exit-drain` | Disable app drain |
| GET | `/service/ops/drain-status` | Drain readiness aggregate |

**Never cache:** `/health`, `/service/health`, `/service/auth/validate`, `/service/ops/*`, auth POSTs.

Drain operator runbook: [DRAIN_SYSTEM.md](DRAIN_SYSTEM.md).

## User media storage

Avatars are **not** stored in Postgres or the container image.

| Item | Value |
|------|--------|
| Volume | `arcori_uploads` → `/data/uploads` in API container |
| Path | `/data/uploads/avatars/{user_id}.webp` |
| DB column | `users.avatar_url` e.g. `/media/avatars/{user_id}.webp` |
| Public URL | `GET /media/avatars/{user_id}.webp` |

| Variable | Purpose |
|----------|---------|
| `UPLOAD_ROOT` | Root upload directory (default `/data/uploads`) |
| `AVATAR_MAX_UPLOAD_BYTES` | Max raw upload (default 2 MB) |
| `AVATAR_MAX_DIMENSION` | Max width/height after resize (default 512) |
| `AVATAR_WEBP_QUALITY` | WebP quality 1–100 (default 82) |

Python deps: `Pillow`, `python-multipart` (required for file uploads).

## WebSocket tiers

| URL | Tier | Auth handshake |
|-----|------|----------------|
| `/ws/public` | public | None — server sends `connected` immediately |
| `/ws/authuser` | authuser | First frame: `type: "auth"` with `payload.access_token` |
| `/ws/service` | service | First frame: `type: "auth"` with `payload.service_key` |

Service key on WebSocket travels in the **first auth frame**, not as an HTTP header. Same `verify_service_key_or_raise` helpers as HTTP. See [PYTHON_DART_BACKEND.md](PYTHON_DART_BACKEND.md) and [WS_SYSTEM.md](WS_SYSTEM.md).

## JWT

- Algorithm: **HS256**
- Access: `JWT_SECRET`, `typ=access`, claim `sub` = user UUID, `jti`
- Refresh: `JWT_REFRESH_SECRET`, `typ=refresh`, `jti` **required**
- Expiry: `JWT_ACCESS_EXPIRES_SECONDS`, `JWT_REFRESH_EXPIRES_SECONDS`

### Refresh rotation + revocation

Redis stores the **current refresh `jti` per user** (`{ARCORI_REFRESH_SESSION_KEY_PREFIX}user:{user_id}`, TTL = refresh lifetime).

| Event | Behavior |
|-------|----------|
| Login / register / convert / dev-login | Issue pair; `SET` current `jti` |
| `POST /public/auth/refresh` | Presented `jti` must match Redis; return **new access + new refresh**; update Redis |
| Refresh with wrong/stolen `jti` | Delete Redis key; `401 invalid_token` (`refresh_reuse_detected`) |
| `POST /public/auth/logout` | Delete Redis key (`refresh_revoked reason=logout`) |
| Delete account / convert guest | Delete Redis key before/after re-issue |

Redis errors on refresh verify are **fail-closed** (reject). Access JWTs are not denylisted (short TTL).

Guards set auth context on the request ContextVar after verification.

**Flutter client:** obtain tokens from FastAPI `/public/auth/register`, `/public/auth/login`, and `/public/auth/refresh` (persist **rotated** `refresh_token`). Logout calls `/public/auth/logout` then clears secure storage. On first launch the app auto-registers a guest via `/public/auth/register` (same SSOT path as full accounts). Local guest credentials are stored in `flutter_secure_storage`. Guests can convert to full accounts in-place (`POST /authuser/user/account/convert-guest`) keeping the same `user_id`. Profile avatars are full-account only. `dev-login` is debug-only. Dart and FastAPI both **validate** access JWTs on HTTP and WS using the same secrets; Dart does not issue tokens for the mobile/web app.

## Environment variables

| Variable | Local (`.env.local`) | Prod (`.env.prod`) |
|----------|----------------------|---------------------|
| `ARCORI_ENV` | `local` | `production` |
| `JWT_SECRET` | dev placeholder | strong random |
| `JWT_REFRESH_SECRET` | dev placeholder | different strong random |
| `SERVICE_KEY` | dev shared key | strong random |
| `ARCORI_ALLOW_DEV_LOGIN` | `true` | `false` |
| `CORS_ALLOWED_ORIGINS` | localhost origins | your HTTPS origin(s) |
| `APP_DEBUG` | `0` | `0` (required) |
| `DATABASE_URL` | local Postgres URL (app role) | compose sets app role; see [POSTGRES_RBAC.md](POSTGRES_RBAC.md) |
| `MIGRATION_DATABASE_URL` | owner URL for Alembic / seed scripts | owner @ `Arcori_postgres` |
| `READONLY_DATABASE_URL` | Adminer / reporting | readonly @ host `:5433` |
| `PG_RBAC_ENABLED` | `0` (single user) | `1` (least privilege) |
| `POSTGRES_APP_USER` / `POSTGRES_APP_PASSWORD` | same as owner when RBAC off | distinct app credentials |
| `POSTGRES_READONLY_USER` / `POSTGRES_READONLY_PASSWORD` | dev placeholder | distinct readonly credentials |
| `REDIS_HOST` / `REDIS_PORT` | `127.0.0.1` / `6379` | compose sets `Arcori_redis` |
| `ARCORI_RATE_LIMIT_ENABLED` | `true` (with Redis) | `true` |
| `ARCORI_REFRESH_SESSION_KEY_PREFIX` | `Arcori:rt:` | Redis current refresh-jti prefix |
| `UPLOAD_ROOT` | `/data/uploads` | `/data/uploads` |
| `AVATAR_MAX_UPLOAD_BYTES` | `2097152` | `2097152` |
| `AVATAR_MAX_DIMENSION` | `512` | `512` |
| `AVATAR_WEBP_QUALITY` | `82` | `82` |

Copy from [`.env.local.sample`](../../.env.local.sample) / [`.env.prod.sample`](../../.env.prod.sample). **Never commit** `.env.local` or `.env.prod`.

## Fail-closed startup

When `ARCORI_ENV=production`:

- App refuses to start if `JWT_SECRET`, `JWT_REFRESH_SECRET`, or `SERVICE_KEY` is missing or still a placeholder (`change-me`, `REPLACE_WITH`).
- `APP_DEBUG=1` is rejected.

## Docker

[`docker/docker-compose.yml`](../../docker/docker-compose.yml) loads `../.env.prod` for `Arcori_api`. Copy `.env.prod.sample` → `.env.prod` on the VPS before `docker compose up`.

The API container is not published on the host in production; Caddy is the public entry point. Debug compose exposes port **8000** and bind-mounts `bin/` for live Python edits.

Upload volume on API service:

```yaml
volumes:
  - arcori_uploads:/data/uploads
```

Postgres is on the internal Docker network (port 5432 exposed locally for IDE debug compose).

## CORS and headers (FastAPI)

- `CORS_ALLOWED_ORIGINS`: comma-separated list; preflight `OPTIONS` supported when origin matches.
- Response headers: `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`.

## Secret rotation

1. Generate new `JWT_SECRET` / `JWT_REFRESH_SECRET` / `SERVICE_KEY`.
2. Update `.env.prod` on VPS and any service-tier clients.
3. Redeploy; existing tokens become invalid (users re-login / refresh fails).
4. Coordinate `SERVICE_KEY` with any internal service clients.

## Rate limiting (HTTP)

Redis fixed-window counters shared across Gunicorn workers. Enabled when `ARCORI_RATE_LIMIT_ENABLED` is truthy.

| Bucket | Key | Default | Applies to |
|--------|-----|---------|------------|
| `global` | client IP | 120 / 60s | All HTTP except allowlist |
| `auth` | client IP | 20 / 60s | `POST /public/auth/*` |
| `auth_identity` | SHA-256 of normalized email (truncated) | 10 / 900s | login + register after body parse |
| `guest_register` | client IP | 5 / 3600s | `register(..., is_guest=True)` in auth service |

**Allowlist (no IP buckets):** `OPTIONS`, `GET /health`, `/service/*`.

Exceeded requests return **429** `{ ok: false, error: { code: "rate_limited", … } }` with `Retry-After` when known. Redis errors fail-open (`rate_limit_store_fail_open` WARNING).

Security log line (stdlib → docker logs):

```text
rate_limit_hit bucket=auth client_ip=… path=… method=POST limit=20 window_s=60 retry_after_s=…
rate_limit_hit bucket=guest_register client_ip=… …
```

## Guest registration

Public `POST /public/auth/register` with `is_guest=true` remains available (Flutter bootstrap). Hardening:

- Email must end with `@arcori.arcori`; otherwise `invalid_request`.
- Full accounts (`is_guest=false`) may **not** use that suffix.
- Dedicated Redis bucket `guest_register` (defaults **5 / 3600s** per IP), in addition to global + `/public/auth` IP limits.

**Deferred:** Play Integrity / App Attest (no attestation in this template yet).

## Soft email verification (full accounts)

When `ARCORI_EMAIL_VERIFICATION_ENABLED` is truthy:

- Full `register` and `convert-guest` create a Redis verify token and send SMTP mail (`MAIL_SMTP_*` / `MAIL_FROM*`).
- Guests never receive verification mail; `email_verified` is `true` only when `users.email_verified_at` is set.
- `POST /public/auth/verify-email` `{ token }` sets `email_verified_at`.
- Mail / App Link path (not a web UI): `{ARCORI_PUBLIC_APP_URL}/arcori-verify-email?token=…` — see [DEEP_LINKS.md](Flutter/DEEP_LINKS.md).
- `POST /authuser/user/account/resend-verification` for full + unverified (guests → forbidden).
- Login is **unchanged** (soft gate — tokens still issued).

SMTP send failures are best-effort (`email_send_fail`); registration still succeeds. Verify Redis lookup errors fail-closed.

```text
email_verification_sent user_id=…
email_verification_ok user_id=…
email_send_fail …
email_verify_store_fail …
```

Never log raw tokens or SMTP passwords.

## Incident debugging

```bash
docker compose -f docker/docker-compose.yml logs Arcori_api 2>&1 | grep -E 'auth_failure|rate_limit_hit|rate_limit_store_fail_open|refresh_rotated|refresh_reuse_detected|refresh_revoked|refresh_session_store_fail|invalid_token|token_expired|email_verification_|email_send_fail|email_verify_store_fail'
```

Never log or paste raw tokens in tickets or chat.

## Charts

- [Security auth flow — diagram](../02_FlowCharts/charts/base/security-auth-flow.html) · [plain English guide](../02_FlowCharts/charts/base/security-auth-flow.guide.html)
- Run `python3 automation/backend/build_nav_and_charts.py` after editing `.mmd` or `.guide.md` sources

## Next (out of scope)

- Google Sign-In → JWT exchange (`GOOGLE_CLIENT_ID` in Flutter env)
- Caddy direct static serve for `/media/*` (optional perf optimization)
- Play Integrity / App Attest for guest register
- Hard login block until email verified
- WS handshake rate limits
- Caddy edge `rate_limit` plugin
