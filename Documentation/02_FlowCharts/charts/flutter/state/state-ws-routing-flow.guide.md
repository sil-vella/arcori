# Flutter WS routing to state — plain English guide

This chart shows what happens when a **WebSocket message arrives** and how it updates the right **Riverpod notifier** without every screen owning its own socket.

## The old way (avoid)

`WsDemoScreen` used to create two `WsClient()` instances inside the widget. That does not scale: duplicate connections, no shared reconnect, and game modules cannot receive server events.

Static **bridges** (globals wired in notifier `build()`) were a temporary glue layer. They are replaced by **`Ref`-backed handlers** registered at bootstrap and applied when `WsConnectionManager` starts.

## The new way (three steps)

1. **`WsConnectionManager`** (core) — owns connections named `dart`, `api`, etc.
2. **`WsChannelRouter`** (core) — looks at the message `channel` and forwards to the right handler
3. **Module notifiers** — handlers call `ref.read(myProvider.notifier)`; screens `ref.watch` slices

## Register a channel handler (module bootstrap)

In `registerMyFeatureState`:

```dart
void registerMyFeatureState(AppStateSink state) {
  state.onWsReady((registrar, ref) {
    registrar.onPrefix('myfeature', (connectionId, data) {
      ref.read(myFeatureProvider.notifier).applyWsPatch(connectionId, data);
    });
  });
}
```

Prefix `myfeature` matches `myfeature` and `myfeature/anything`.

**Replay tip:** if your provider is `autoDispose` and the screen may mount after messages arrive, add a replay notifier (see `example_module_replay.dart`). The WS handler only **stores** on replay; the notifier **listens** for live updates while mounted and applies pending replay on first `build()`.

## Connect and send from a screen

```dart
final auth = ref.read(authProvider);
final manager = ref.read(wsConnectionManagerProvider.notifier);

await manager.connect(
  'dart',
  url: WsConfig.dartAuthuserUrl,
  accessToken: auth.accessToken,
);

await manager.send(
  'dart',
  type: 'event',
  channel: 'demo/echo',
  payload: {'text': 'hello'},
);
```

## Auth and reconnect (Flutter client only)

When the JWT changes (login / refresh), `WsConnectionManager` **reconnects** open sockets with the new token.

When the user logs out, it **disconnects all** (no auto-reconnect).

**Unexpected socket drop:** `WsClient.connectionClosed` → exponential backoff (1s–30s) → reconnect. Endpoints stay registered until intentional `disconnect()`.

WS errors like `token_expired`: refresh access token → reconnect.

**Re-subscribe:** after each (re)connect, `AppStateSink.onWsReconnect` hooks run (e.g. WS Demo re-sends `demo/room` subscribe). Backends do not reconnect — they wait for the new socket. See [state-ws-reconnect-flow](state-ws-reconnect-flow.html).

## Selective rebuild tip

On a high-frequency screen, watch only what you need:

```dart
final slice = ref.watch(
  exampleModuleProvider.select((s) => (s.revision, s.message)),
);
```

That avoids rebuilding the whole screen on every WS tick.

## Try it

1. Login at `/login` if prompted → drawer **WS Demo** → **Connect both WS** → **Subscribe room (Dart)**
2. Connection log fills from `wsConnectionManagerProvider`
3. Demo channel log fills from `wsDemoLogProvider` when `demo/*` frames arrive
4. Restart Dart/API container — log should show backoff reconnect + re-subscribe

## Related

- [ws-system-flow](../../base/ws-system-flow.html) — server-side WS tiers (FastAPI + Dart)
- [WS_SYSTEM.md](../../../../03_Base/WS_SYSTEM.md) — full technical doc
- [state-ws-reconnect-flow](state-ws-reconnect-flow.html) — drop reconnect + re-subscribe hooks (Flutter only)
- [STATE_SYSTEM.md](../../../../03_Base/Flutter/STATE_SYSTEM.md) — full checklist: **Add a realtime feature**
