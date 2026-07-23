# arcori — Flutter state system

Technical guide for modular, tiered application state in **flutter_base_06**. Built on **Riverpod** with **sink-based bootstrap wiring** (same pattern as routes and drawer). Cross-stack reference: [EXAMPLE_MODULE.md](../EXAMPLE_MODULE.md). For server-side WS tiers, see [WS_SYSTEM.md](../WS_SYSTEM.md). For Dart/Python state infrastructure, see [DART_STATE_SYSTEM.md](../DART_STATE_SYSTEM.md) and [PYTHON_STATE_SYSTEM.md](../PYTHON_STATE_SYSTEM.md).

**Charts + plain English guides:**

- [State system flow — diagram](../02_FlowCharts/charts/flutter/state/state-system-flow.html) · [guide](../02_FlowCharts/charts/flutter/state/state-system-flow.guide.html) — tiers, Riverpod, bootstrap
- [WS routing to state — diagram](../02_FlowCharts/charts/flutter/state/state-ws-routing-flow.html) · [guide](../02_FlowCharts/charts/flutter/state/state-ws-routing-flow.guide.html) — manager, router, notifiers
- [WS reconnect — diagram](../02_FlowCharts/charts/flutter/state/state-ws-reconnect-flow.html) · [guide](../02_FlowCharts/charts/flutter/state/state-ws-reconnect-flow.guide.html) — **Flutter only**: backoff, re-subscribe hooks
- [State module registration — diagram](../02_FlowCharts/charts/flutter/state/state-module-registration-flow.html) · [guide](../02_FlowCharts/charts/flutter/state/state-module-registration-flow.guide.html) — add a new module's state

Regenerate charts: `python3 automation/backend/build_nav_and_charts.py` or `wfcharts` from project root.

## Overview

State is split into **four tiers**. Modules own tier 3 (domain) and tier 4 (ephemeral UI). Core owns tier 1 (session) and tier 2 (transport).

| Tier | Owner | Examples | Lifetime |
|------|-------|----------|----------|
| 1 — Core session | `core/state/auth` | Access token, user id | App |
| 2 — Transport | `core/ws` | WS connections, reconnect, channel router | App |
| 3 — Feature domain | `modules/<feature>/state` | Example revision, message | Route / module scope |
| 4 — Ephemeral UI | Screen | Form fields, animations | Widget |

```text
Bootstrap (sinks)                    Runtime (Riverpod)
─────────────────                    ──────────────────
registerApplicationModules           ProviderScope
  registerCoreState(state)             authProvider
  registerWsDemoState(state)           wsConnectionManagerProvider
  registerExampleModuleState(state)      exampleModuleProvider
    onWsReady → handler factories      screens: ref.watch / ref.read
         ↓ applied with Ref at WS start
```

## Design principles

1. **Sinks wire; contracts read.** `AppStateSink` registers WS channel handler *factories* at startup. Handlers receive `Ref` when `WsConnectionManager` starts and call `ref.read(myProvider.notifier)` — no static bridges.
2. **No monolithic app store.** Each domain has its own notifier. Use selective `ref.watch(provider.select(...))`.
3. **Core owns auth + WS transport.** One reconnect/token story; modules register channel handlers only.
4. **Example module** shows tier-3 + WS replay — see [EXAMPLE_MODULE.md](../EXAMPLE_MODULE.md). Copy the folder for real features; do not grow it in place.
5. **Screens do not own `WsClient`.** Use `WsConnectionManager` via `wsConnectionManagerProvider`.

## Bootstrap

`startApp()` in `app_init.dart`:

```dart
resetAppStateRegistry();
registerApplicationModules(
  appRouteSink,
  appDrawerSink,
  appBarSink,
  appStateSink,
);
runApp(AppProviderScope(child: _RootApp(router: router)));
```

`registerApplicationModules` calls, in order:

| Function | Module | Purpose |
|----------|--------|---------|
| `registerCoreState` | core | Placeholder for core WS handlers |
| `registerWsDemoState` | ws_demo | `demo/*` channel → `wsDemoLogProvider` |
| `registerExampleModuleState` | example_module | `example/*` → `exampleModuleProvider` + replay |

## AppStateSink contract

```dart
abstract interface class AppStateSink {
  void onWsReady(
    void Function(WsChannelRegistrar registrar, Ref ref) register,
  );
}
```

Registrations are stored at bootstrap. `buildWsChannelRouter(ref)` applies them when `WsConnectionManager.build()` runs inside `ProviderScope`.

## Tier 1 — Auth

| File | Role |
|------|------|
| `core/state/auth/auth_state.dart` | Session snapshot + `SessionStatus` |
| `core/state/auth/auth_providers.dart` | `bootstrap`, `devLogin`, `refreshAccessToken`, `logout` |
| `core/state/auth/auth_token_storage.dart` | Secure persistence (`flutter_secure_storage`) |
| `core/http/auth_api_client.dart` | FastAPI `/public/auth/*` (single client issuer) |
| `modules/auth/login_screen.dart` | `/login` route |
| `core/navigation/auth_redirect.dart` | Option A — protect `/ws-demo`, `/example-module` only |

On launch: `bootstrap()` restores tokens and refreshes access. Protected routes redirect to `/login?from=…`. WS errors with `token_expired` trigger refresh then reconnect.

```dart
// Dev login (template) — prefer /login screen; issues via FastAPI only
await ref.read(authProvider.notifier).devLogin();

// Cross-module read
final session = ref.watch(authSessionReaderProvider);
if (session.isAuthenticated) { … }
```

## Tier 2 — WebSocket transport

| File | Role |
|------|------|
| `core/ws/ws_connection_manager.dart` | Shared clients, backoff reconnect on drop, auth refresh reconnect |
| `core/ws/ws_reconnect_policy.dart` | Exponential backoff (1s → 30s cap) |
| `core/ws/ws_channel_router.dart` | Prefix-based inbound demux |
| `core/state/contracts/ws_connection_reader.dart` | Connection status contract |

```dart
final manager = ref.read(wsConnectionManagerProvider.notifier);
await manager.connect('dart', url: WsConfig.dartAuthuserUrl, accessToken: token);
await manager.send('dart', type: 'ping', channel: 'system');
```

**Error policy:** WS errors run through `actionForApiError(..., isWebSocket: true)` in `error_policy.dart`. `reconnectWs` triggers reconnect with the current auth token.

**Auth listener:** When `authProvider` token changes, open connections reconnect; on logout, all connections disconnect.

**Drop reconnect:** `WsClient.connectionClosed` → manager schedules reconnect with exponential backoff. Endpoints stay registered until intentional `disconnect()`.

**Re-subscribe hooks:** modules register `AppStateSink.onWsReconnect((connectionId, ref, send) { … })` — runs after each successful (re)connect. See `ws_demo` room subscriptions.

## Tier 3 — example_module (reference)

| File | Role |
|------|------|
| `modules/example_module/state/example_module_state.dart` | Immutable snapshot |
| `modules/example_module/state/example_module_notifier.dart` | `exampleModuleProvider` |
| `modules/example_module/state/example_module_replay.dart` | WS replay inbox |
| `modules/example_module/register_example_module_state.dart` | `example/*` WS handler |

```dart
final slice = ref.watch(
  exampleModuleProvider.select((s) => (s.revision, s.message)),
);
```

See [EXAMPLE_MODULE.md](../EXAMPLE_MODULE.md) for Dart/Python counterparts.

## WS channel routing

Handlers register prefixes and write through `Ref`:

```dart
state.onWsReady((registrar, ref) {
  registrar.onPrefix('example', (connectionId, data) {
    ref.read(exampleModuleReplayProvider.notifier).store(connectionId, data);
  });
});
```

`ExampleModuleNotifier` listens to replay for live updates. `WsChannelRouter.dispatch` matches exact channel or `prefix/...`.

## Add a realtime feature — checklist

Copy `example_module/` as a starting point. See [EXAMPLE_MODULE.md](../EXAMPLE_MODULE.md).

1. **Notifier + provider** — module-owned snapshot + optional replay notifier.
2. **Register WS handler** — `onWsReady((registrar, ref) { … })` — never static globals.
3. **Optional reconnect hook** — `onWsReconnect((connectionId, ref, send) { … })` to re-subscribe rooms/channels after drop (Flutter only; see [state-ws-reconnect-flow](../02_FlowCharts/charts/flutter/state/state-ws-reconnect-flow.html)).
4. **Wire bootstrap** — `module_registry.dart`.
5. **Routes + drawer** — see [NAVIGATION_SYSTEM.md](NAVIGATION_SYSTEM.md).
6. **Screen** — `ConsumerWidget`; use `wsConnectionManagerProvider`, not `WsClient`.
7. **Hot fields** — `ref.watch(provider.select(...))`.
8. **Channel names** — align with Dart backend (`example/*`, `demo/*`, …).
9. **Tests** — notifier unit test + `buildWsChannelRouter(ref)` dispatch + optional reconnect hook test.

## Adding state to a new module (non-realtime)

1. Create `modules/<name>/state/<name>_notifier.dart` with Riverpod provider(s).
2. Optional: `modules/<name>/contracts/*_reader.dart` for cross-module reads.
3. Create `register<Name>State(AppStateSink state)` with `onWsReady` handlers if needed.
4. Wire in `module_registry.dart`.
5. Screens: `ConsumerWidget` / `ConsumerStatefulWidget` + `ref.watch` / `ref.read`.
6. Use `autoDispose` for route-scoped domain state.

## Testing

Shared boot helper: `test/helpers/app_test_boot.dart`

```dart
await bootTestApp(tester, overrides: [
  authProvider.overrideWith(() => FakeAuthNotifier()),
]);
```

Unit tests:

| File | Coverage |
|------|----------|
| `test/core/ws/ws_channel_router_test.dart` | Channel demux |
| `test/core/state/auth_notifier_test.dart` | Auth session |
| `test/modules/example_module/example_module_notifier_test.dart` | Example WS + replay |

Reset sequence in tests:

```dart
resetAppStateRegistry();
registerApplicationModules(..., appStateSink);
```

Capture `Ref` in unit tests when exercising the router:

```dart
late Ref ref;
container.read(Provider((r) { ref = r; return 0; }));
final router = buildWsChannelRouter(ref);
router.dispatch('dart', {'channel': 'example/state', 'payload': {...}});
```

## Cross-module rules

| Rule | Rationale |
|------|-----------|
| Do not import another module's notifier impl | Use reader contracts |
| Do not register screen items on `AppStateSink` for UI state | Use `AppBarRegistrar` or local state |
| Do not create `WsClient` in screens | Use `WsConnectionManager` |
| Prefer `select()` for hot gameplay fields | Fewer rebuilds |
| Do not use static bridges for WS → state | Use `Ref` in `onWsReady` handlers |

## File reference

```
lib/core/state/
  contracts/          app_state_sink, auth_session_reader, ws_connection_reader
  auth/               auth_state, auth_providers
  app_state_registry.dart
  register_core_state.dart
  provider_scope_root.dart   AppProviderScope

lib/core/ws/
  ws_connection_manager.dart
  ws_channel_router.dart

lib/modules/<feature>/
  state/              notifiers, optional replay
  register_*_state.dart
  contracts/          optional reader interfaces
```

## Future work

- Debounce high-frequency WS patches from server
- Google Sign-In token exchange on FastAPI
