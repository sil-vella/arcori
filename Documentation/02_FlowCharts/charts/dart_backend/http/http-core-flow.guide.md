# Dart HTTP core flow

This chart shows how a request moves through **dart_bkend_base_02** from `app.dart` to your feature handler.

## Start here — one sentence

The server builds a **route table** at startup, then every HTTP request is matched by method + path and run through the right guard (public, JWT, or service key).

## Startup order

1. **`app.dart`** → `startApp()` in `app_init.dart`
2. **`createHttpHandler()`** in `core/http/http_app.dart`:
   - Clears old routes (`resetRouteRegistry`)
   - Calls `registerApplicationRoutes()` from `module_registry.dart`
   - Returns `buildApplicationHandler()` — the Shelf dispatcher
3. **`serve()`** binds to `PORT` (default **8080**)

## Three route tiers (same idea as FastAPI)

Register paths **without** the tier prefix in your module code:

| You register | Visitors call |
|--------------|---------------|
| `publicGet('/', …)` | `GET /` |
| `authuserGet('/user/profile', …)` | `GET /authuser/user/profile` |
| `servicePost('/auth/validate', …)` | `POST /service/auth/validate` |

Guards run automatically for authuser and service routes.

## Example: add a public route

In your feature module:

```dart
routes.publicGet(
  '/hello',
  (Request request) async => res.jsonOk({'message': 'hello'}),
);
```

Test (with debug compose running — Dart on `:8080`):

```bash
curl -s http://127.0.0.1:8080/health | jq .
curl -s http://127.0.0.1:8080/hello | jq .
```

Local backends are started via `docker compose -f docker/docker-compose.debug.yml` (see [00_MASTER_PLAN.md](../../../../00_Active_Plans/00_MASTER_PLAN.md)), not host `dart run`.

## Where to look in the repo

| File | Role |
|------|------|
| `bin/app_init.dart` | Starts Shelf server |
| `bin/core/http/http_app.dart` | Wires registry + handler |
| `bin/core/http/service/routes.dart` | Route table + tier prefixes |
| `bin/modules/module_registry.dart` | Imports all feature modules |
