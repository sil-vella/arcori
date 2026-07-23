# Module registry flow

This chart shows **module_registry.dart** — the single place where feature modules plug into the Dart backend.

## Why one registry file?

Instead of scattering imports across `app.dart`, you add new features in one composition root:

- Easier code review (“what routes exist?”)
- Same pattern for HTTP today and WebSocket / jobs later

## What runs today

`registerApplicationRoutes()` in `bin/modules/module_registry.dart`:

1. `requireSecretsForProduction()` — fail closed if prod secrets are missing
2. `registerUserRoutes` — public `/`, `/health`, authuser profile
3. `registerServiceRoutes` — service-tier health
4. `registerAuthRoutes` — dev-login, refresh, validate

## Add a new HTTP module (copy-paste pattern)

**1. Create** `bin/modules/widgets/widget_app.dart`:

```dart
void registerWidgetRoutes(
  ApplicationRouteSink routes,
  HttpResponseContract res,
) {
  routes.publicGet(
    '/widgets/list',
    (Request request) async => res.jsonOk({'widgets': []}),
  );
}
```

**2. Wire it** in `module_registry.dart`:

```dart
import 'widgets/widget_app.dart';

void registerApplicationRoutes() {
  requireSecretsForProduction();
  registerUserRoutes(applicationRoutes, httpResponses);
  registerServiceRoutes(applicationRoutes, httpResponses);
  registerAuthRoutes(applicationRoutes, httpResponses);
  registerWidgetRoutes(applicationRoutes, httpResponses); // add this
}
```

**3. Test:**

```bash
dart run bin/app.dart
curl -s http://127.0.0.1:8080/widgets/list | jq .
```

## WebSocket (implemented)

`registerApplicationWsChannels()` wires `modules/ws/` demo channels. HTTP and WS share `core/auth` only — no game logic yet.

See [WS_SYSTEM.md](../../../03_Base/WS_SYSTEM.md).

## FastAPI parity

Python uses the same idea: `bin/modules/module_registry.py` calls each `register_*_routes` function. Keep Dart and FastAPI route names aligned when both expose the same API.
