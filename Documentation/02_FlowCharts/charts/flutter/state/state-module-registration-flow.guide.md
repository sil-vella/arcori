# Flutter state module registration — plain English guide

This chart shows how to **add a new feature module's state** the same way you add routes and drawer rows.

## Pattern (mirror routes)

| Concern | File | Register function |
|---------|------|-------------------|
| Routes | `my_feature_routes.dart` | `registerMyFeatureRoutes(routes)` |
| Drawer | `my_feature_drawer.dart` | `registerMyFeatureDrawer(drawer)` |
| State / WS | `register_my_feature_state.dart` | `registerMyFeatureState(state)` |
| Screen | `my_feature_screen.dart` | `ConsumerWidget` + providers |

## Step-by-step: add `inventory` module state

**1. Create notifier** `modules/inventory/state/inventory_notifier.dart`:

```dart
class InventoryState {
  const InventoryState({this.items = const []});
  final List<String> items;
}

class InventoryNotifier extends Notifier<InventoryState> {
  @override
  InventoryState build() => const InventoryState();

  void applyWsPatch(String connectionId, Map<String, dynamic> data) {
    // parse payload, update state
  }
}

final inventoryProvider =
    NotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);
```

Use `NotifierProvider.autoDispose` if state should die when leaving the route. Add a replay notifier if WS can arrive before the screen mounts.

**2. WS handler** `register_inventory_state.dart`:

```dart
void registerInventoryState(AppStateSink state) {
  state.onWsReady((registrar, ref) {
    registrar.onPrefix('inventory', (connectionId, data) {
      ref.read(inventoryProvider.notifier).applyWsPatch(connectionId, data);
    });
  });
}
```

No static bridges — `Ref` is passed when the router is built at WS manager start.

**Optional — reconnect hook** (Flutter only; server forgets room membership on disconnect):

```dart
void registerInventoryState(AppStateSink state) {
  state.onWsReady((registrar, ref) { /* … */ });

  state.onWsReconnect((connectionId, ref, send) async {
    final rooms = ref.read(inventorySubscriptionsProvider)[connectionId];
    if (rooms == null) return;
    for (final roomId in rooms) {
      await send(type: 'subscribe', channel: 'demo/room', payload: {'room_id': roomId});
    }
  });
}
```

See [state-ws-reconnect-flow](state-ws-reconnect-flow.html).

**3. Wire** `module_registry.dart`:

```dart
registerInventoryState(state);
registerInventoryRoutes(routes);
registerInventoryDrawer(drawer);
```

**4. Screen**:

```dart
class InventoryScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryProvider.select((s) => s.items));
    return ListView(children: items.map(Text.new).toList());
  }
}
```

## Realtime feature checklist (short)

See [STATE_SYSTEM.md](../../../../03_Base/Flutter/STATE_SYSTEM.md) for the full list. In order:

1. Notifier + provider (+ optional replay for autoDispose)
2. `register_*_state.dart` with `onWsReady((registrar, ref) { … })`
3. Optional `onWsReconnect` if module uses subscribe/rooms
4. `module_registry.dart`
5. Routes + drawer
6. `ConsumerWidget` screen — connect via `wsConnectionManagerProvider`, not `WsClient`
7. `select()` for hot fields
8. Align channel prefix with backend
9. Tests: notifier unit + `buildWsChannelRouter(ref)` dispatch

## What NOT to put in AppStateSink

- Screen form fields (tier 4 — local `setState`)
- AppBar titles (use `AppBarRegistrar`)
- A global map like `state.get('foo')` — use typed providers instead
- Static bridge globals — use `ref.read(...)` in handlers

## Tests

```dart
await bootTestApp(tester, overrides: [
  authProvider.overrideWith(() => FakeAuthNotifier()),
]);
```

Handler integration:

```dart
late Ref ref;
container.read(Provider((r) { ref = r; return 0; }));
final router = buildWsChannelRouter(ref);
router.dispatch('dart', {'channel': 'inventory/sync', 'payload': {...}});
```

Helper: `test/helpers/app_test_boot.dart`

## Parity with Dart backend

Dart uses `module_registry.dart` + `registerApplicationWsChannels()`. Flutter uses `AppStateSink.onWsReady`. Keep **channel prefix names** aligned (`example/*`, `demo/*`, etc.).

## Related

- [state-system-flow](state-system-flow.html) — tiers and Riverpod overview
- [state-ws-reconnect-flow](state-ws-reconnect-flow.html) — drop reconnect (Flutter only)
- [module-registry-flow](../../dart_backend/module_registry/module-registry-flow.html) — Dart backend registry
