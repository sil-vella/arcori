# Error handling flow

This chart shows how **Arcori** turns failures into one JSON shape on HTTP and WebSocket, and splits **core** vs **module** error codes.

## One envelope everywhere

Success and failure use the same JSON on REST and WebSocket:

```json
{ "ok": false, "error": { "code": "token_expired", "message": "Access token expired" } }
```

HTTP also sets a status code (401, 404, 500, …). WebSocket sends the same body as a **frame** — clients must read `error.code`, not status alone.

## Two tiers of error codes

| Tier | Where defined | Code shape | Example |
|------|---------------|------------|---------|
| **Core** | `core/errors/error_codes.*` | short snake_case | `token_expired`, `not_found` |
| **Module** | `modules/{x}/{x}_errors.*` | `{module}/{reason}` | `ws/demo_room/not_implemented` |

Modules register codes at startup through `ModuleErrorRegistrar` (same moment as routes and WS channels in `module_registry`).

Handlers raise `AppError(spec)` — never inline `"some_random_code"` strings.

## Server flow

1. **HTTP** — `authuser_guard` / `service_guard` call shared `verify_*` helpers → `AppError` → JSON response.
2. **WebSocket** — dispatcher runs auth handshake with the same verify helpers; channel handlers raise `AppError`; fatal auth errors close the socket after the error frame.
3. **500** — FastAPI exception handlers map unknown exceptions to `internal_error`.

Structured logs use `code=` and `reason=` — never JWT or service keys.

## Flutter client

`ApiError.fromEnvelope` parses the wire format. `error_policy.dart` maps **core** codes to actions (refresh, re-login, reconnect WS, show message).

Full catalog: [ERROR_SYSTEM.md](../../../03_Base/ERROR_SYSTEM.md). WS tiers: [ws-system-flow](ws-system-flow.html).

## Try it locally

```bash
# Missing Bearer on protected route → unauthorized
curl -s http://127.0.0.1:8000/authuser/user/profile | jq .

# WebSocket ping after dev-login (see PYTHON_DART_BACKEND.md smoke test)
```

Related: [SECURITY_SYSTEM.md](../../../03_Base/SECURITY_SYSTEM.md) (auth codes).
