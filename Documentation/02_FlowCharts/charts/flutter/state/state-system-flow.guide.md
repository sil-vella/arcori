# Flutter state system — plain English guide

This chart shows how **flutter_base_06** manages shared app state with **Riverpod** and the same **sink + contract** pattern used for routes and drawer.

## What problem does this solve?

Without a plan, each screen keeps its own token, WebSocket clients, and game data in `setState`. That leads to duplicate connections, stale UI, and modules that cannot talk to each other safely.

This template splits state into **four tiers** and uses **one bootstrap registry** so modules plug in cleanly.

## The four tiers (simple version)

| Tier | What it is | Example | How long it lives |
|------|------------|---------|-------------------|
| 1 — Session | Who is logged in | JWT, user id | Whole app |
| 2 — Transport | How we talk to the server | WS connect / reconnect / backoff | Whole app |
| 3 — Domain | Feature data | Example revision, message | While on that screen/route |
| 4 — UI fluff | Form fields, animations | Text field value | While widget is on screen |

**Rule of thumb:** hot domain data is tier 3; login token is tier 1; never put tier 3 in a global singleton unless you mean to.

## What runs at startup

`startApp()` in `app_init.dart`:

1. Reset registries (routes, drawer, app bar, **state**)
2. `registerApplicationModules(..., appStateSink)` — each module registers WS handlers
3. Wrap the app in `AppProviderScope` (Riverpod)

## Read state in a screen

Use `ConsumerWidget` and `ref.watch`:

```dart
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isAuthenticated) {
      return const Text('Please log in');
    }
    return Text('Hello ${auth.userId}');
  }
}
```

## Cross-module reads (use contracts)

Other modules should not import `AuthNotifier` directly:

```dart
final session = ref.watch(authSessionReaderProvider);
if (session.isAuthenticated) {
  final token = session.accessToken;
}
```

## Try it in the app

1. `wfrun` → launch Flutter (Chrome)
2. Drawer → **WS Demo** — connect + optional room subscribe (uses tier 1 + 2; drop reconnect is Flutter-only)
3. Drawer → **Example module** — send `example/state` (uses tier 3)

## More detail

- [STATE_SYSTEM.md](../../../../03_Base/Flutter/STATE_SYSTEM.md) — full technical doc + **Add a realtime feature** checklist
- [state-ws-routing-flow](state-ws-routing-flow.html) — how WS messages reach notifiers via `Ref`
- [state-module-registration-flow](state-module-registration-flow.html) — add a new module's state
