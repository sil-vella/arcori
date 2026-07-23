# Feature module HTTP flow

This chart explains how **you** add an API endpoint in Dart without touching the low-level Shelf wiring.

## Simple story (5 steps)

1. Write a small function — what JSON to return for one path.
2. Pick a tier: **public**, **authuser** (logged-in user), or **service** (internal).
3. Register it in a feature file like `user/user_app.dart`.
4. Make sure `module_registry.dart` calls your `register*Routes` function.
5. The framework adds `/authuser` or `/service` for you — your path string stays short.

## Example: protected profile route

`modules/user/user_app.dart` (simplified):

```dart
routes.authuserGet(
  '/user/profile',
  (Request request) async => res.jsonOk({
    'user_id': authUserIdFrom(request),
    'profile': 'example',
  }),
);
```

The guard verifies the Bearer JWT **before** your handler runs. You read `user_id` from request context — you do not parse the token yourself.

Test after `dev-login` on FastAPI **or** Dart (same JWT secrets):

```bash
# Get token from FastAPI or Dart dev-login, then:
curl -s http://127.0.0.1:8080/authuser/user/profile \
  -H "Authorization: Bearer <access_token>" | jq .
```

## Example: internal service route

```dart
routes.serviceGet(
  '/health',
  (Request request) async => res.jsonOk({'status': 'up'}),
);
```

Callers must send `X-Service-Key` matching `SERVICE_KEY` in the environment.

## Registration checklist

- [ ] Handler in `modules/<feature>/<feature>_app.dart`
- [ ] `register<Feature>Routes(applicationRoutes, httpResponses)` exists
- [ ] `module_registry.dart` calls it inside `registerApplicationRoutes()`
- [ ] Path does **not** include `/authuser` or `/service` in the string

## Common mistakes

| Mistake | Symptom |
|---------|---------|
| Path includes `/authuser/...` in `authuserGet` | Double prefix → 404 |
| Forgot `SERVICE_KEY` env | All `/service/*` return 403 |
| Bearer missing on authuser route | 401 before your code runs |
