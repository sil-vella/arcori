# Error system (Arcori)

Shared error handling for FastAPI, Dart Shelf, and Flutter. One JSON envelope on HTTP and WebSocket; two tiers of `code` strings; client retry policy in Flutter.

**Chart + plain English:** [error-handling-flow](../02_FlowCharts/charts/base/error-handling-flow.html)

Related: [SECURITY_SYSTEM.md](SECURITY_SYSTEM.md) (auth failures), [PRODUCTION_SYSTEM.md](PRODUCTION_SYSTEM.md) (500 / slow requests), [WS_SYSTEM.md](WS_SYSTEM.md) (WebSocket tiers).

---

## Wire format

```json
{ "ok": false, "error": { "code": "token_expired", "message": "Access token expired" } }
```

- **HTTP** — same body plus `http_status` from the error spec (401, 404, 500, …).
- **WebSocket** — same body as a text frame; no status code. Clients **must** branch on `error.code`.

Success shape (unchanged): `{ "ok": true, "data": { ... } }`.

---

## Two-tier codes

### Core (framework-owned)

Defined only in `core/errors/error_codes.*`. Modules must not register or reuse these strings.

| `code` | HTTP | WS fatal? | Flutter policy |
|--------|------|-----------|----------------|
| `unauthorized` | 401 | yes (auth tiers) | re-login / WS re-auth |
| `token_expired` | 401 | yes | REST refresh → retry; **Flutter** WS refresh → reconnect |
| `invalid_token` | 401 | yes | re-login |
| `forbidden` | 403 | yes (service) | show message, stop |
| `not_found` | 404 | no | fix path or channel |
| `invalid_json` | 400 | no | fix payload |
| `invalid_message` | 400 | no | fix payload |
| `not_implemented` | 501 | no | feature stub |
| `rate_limited` | 429 | no | show message (retry later) |
| `internal_error` | 500 | no (v1) | retry / reconnect |

### Module (feature-owned)

Shape: `{module}/{reason}` — e.g. `ws/demo_room/not_implemented`.

1. Declare specs in `modules/{x}/{x}_errors.py` or `.dart`.
2. Register via `register_*_errors(module_error_registrar)` from `module_registry`.
3. Raise `AppError(MODULE_SPEC)` in handlers — no raw strings at throw sites.
4. Registrar rejects collisions with core codes and duplicate module codes.

---

## Server implementation

| Piece | Python | Dart |
|-------|--------|------|
| Spec + catalog | `core/errors/error_codes.py` | `core/errors/error_codes.dart` |
| Raise in handlers | `core/errors/app_error.py` | `core/errors/app_error.dart` |
| Module registry | `core/errors/module_error_registry.py` | `core/errors/module_error_registry.dart` |
| Auth dedupe | `core/auth/verify_access.py`, `verify_service_key.py` | same under `core/auth/` |
| HTTP boundary | FastAPI exception handlers in `prod_runtime.py` | `errorMiddleware()` in `http_app` / `ws_app` |
| WS policy | `core/ws/ws_dispatcher.py` | `core/ws/ws_dispatcher.dart` |

Startup order (both stacks): `reset_module_error_registry()` → `register_application_errors()` → routes → WS channels.

### WebSocket policy (v1)

| Situation | Action |
|-----------|--------|
| Auth failure | error frame + **close** |
| Bad JSON / invalid message | error frame, stay open |
| Unknown channel | `not_found` frame, stay open |
| Handler `AppError` | error frame; close if `spec.fatal_ws` |
| Uncaught exception | `internal_error` frame + log, stay open |

Reference module: `modules/ws/demo_errors.*`.

---

## Flutter client

| File | Role |
|------|------|
| `lib/core/errors/api_error.dart` | Parse envelope; `CoreApiErrorCode` vs `ModuleApiErrorCode` |
| `lib/core/errors/error_policy.dart` | `actionFor(code, isWebSocket: …)` → `reconnectWs` on WS |
| `lib/core/ws/ws_client.dart` | Emits `ApiError` on error frames; `connectionClosed` on drop |
| `lib/core/ws/ws_connection_manager.dart` | Executes reconnect: refresh + reconnect, or backoff on drop |

Reconnect with backoff and `onWsReconnect` hooks are **Flutter-only** — see [state-ws-reconnect-flow](../02_FlowCharts/charts/flutter/state/state-ws-reconnect-flow.html).

Module codes default to `showMessage` unless a feature registers custom UI later.

---

## Logging

Follow `.cursor/rules/logging-rule.mdc`. Typical fields:

- Auth: `auth_failure reason= path=` or `ws_error tier= code= reason=auth`
- Refresh session: `refresh_rotated` / `refresh_reuse_detected` / `refresh_revoked reason=` / `refresh_session_store_fail`
- Rate limit: `rate_limit_hit bucket= …` (stdlib → docker logs); Redis down: `rate_limit_store_fail_open`
- Handler bug: `internal_error type= path=` (traceback if `LOG_TRACEBACKS`)
- Never log JWT, refresh token, or `SERVICE_KEY`.

---

## Grep cheat sheet

```bash
# Core catalog
rg 'ErrorSpec\(' app_codebase/python_base_05/bin/core/errors/
rg 'const .* = ErrorSpec' app_codebase/dart_bkend_base_02/bin/core/errors/

# Module codes
rg 'register_.*_errors' app_codebase/*/bin/modules/
rg 'AppError\(' app_codebase/

# Client policy
rg 'actionFor|ApiError' app_codebase/flutter_base_06/lib/core/errors/
```

---

## Tests

- Python: `app_codebase/python_base_05/test/test_app_error.py`, `test/test_ws_auth_ping.py`
- Dart: `app_codebase/dart_bkend_base_02/test/app_error_test.dart`, `test/ws_auth_ping_test.dart`
- Flutter: `app_codebase/flutter_base_06/test/core/errors/api_error_test.dart`
