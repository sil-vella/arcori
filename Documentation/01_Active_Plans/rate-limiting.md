# HTTP rate limiting

**Status**: Completed  
**Created**: 2026-07-23  
**Last Updated**: 2026-07-23

## Objective

Redis-backed HTTP rate limiting with a general per-IP API ceiling plus stricter limits on `/public/auth/*` and an email-keyed bucket on login/register. Hits are logged via stdlib (`rate_limit_hit`) for `docker compose logs`.

## Implementation Steps

- [x] Add `Arcori_redis` to prod compose + env samples
- [x] `rate_limit_config` + `redis_rate_limiter` + core `RATE_LIMITED` (429)
- [x] `rate_limit_guard` wired after drain in `_production_middleware`
- [x] Email identity bucket in `auth_service` login/register
- [x] Flutter `rate_limited` + error policy / auth messages
- [x] Python unit tests
- [x] SECURITY / ERROR / PRODUCTION docs + this plan

## Current Progress

Core FastAPI path and Flutter policy landed. Defaults: global 120/60s, auth IP 20/60s, auth identity 10/900s, guest_register 5/3600s (see [guest-register-harden.md](guest-register-harden.md)).

## Next Steps

- Optional: rebuild security-auth-flow HTML via `build_nav_and_charts.py` after guide edit
- Optional later: WS handshake limits, Caddy edge limits

## Files Modified

- `docker/docker-compose.yml`, `docker/docker-compose.debug.yml`
- `.env.local.sample`, `.env.prod.sample`
- `app_codebase/python_base_05/bin/core/rate_limit/*`
- `app_codebase/python_base_05/bin/core/http/middleware/rate_limit_guard.py`
- `app_codebase/python_base_05/bin/core/utils/prod_runtime.py`
- `app_codebase/python_base_05/bin/core/errors/error_codes.py`, `app_error.py`
- `app_codebase/python_base_05/bin/modules/auth/auth_service.py`
- `app_codebase/python_base_05/tests/core/rate_limit/test_rate_limit.py`
- Flutter + Dart core error catalogs
- `Documentation/03_Base/SECURITY_SYSTEM.md`, `ERROR_SYSTEM.md`, `PRODUCTION_SYSTEM.md`

## Notes

- Redis errors fail-open (`rate_limit_store_fail_open`).
- Do not use `customlog` for rate-limit security events.
- Incident grep: `rate_limit_hit|rate_limit_store_fail_open|auth_failure`
- Guest register bucket is enforced in `auth_service`, not only middleware.
