# Flutter WS reconnect — plain English guide

**Flutter client only.** FastAPI and Dart backends do not reconnect — they accept a new socket when the client comes back.

## What triggers reconnect?

| Trigger | Behavior |
|---------|----------|
| **Socket drop** | `WsClient.onDone` (not intentional `disconnect()`) → `connectionClosed` → backoff → reconnect |
| **Connect failure** | Same backoff loop |
| **JWT changes** (login / refresh) | Immediate `reconnectAll()` with new token |
| **`token_expired` WS error** | Refresh access token → reconnect that connection |
| **Logout / `disconnect()`** | Cancel timers; endpoint removed — **no** auto-reconnect |

## Backoff

`WsReconnectPolicy`: starts at **1s**, doubles each attempt, caps at **30s**. Attempt counter resets on successful connect.

Endpoints (`url` per `connectionId`) stay registered until you call `disconnect()` — so a drop does not forget which servers to rejoin.

## Re-subscribe hooks

After every successful (re)connect, the manager runs **`AppStateSink.onWsReconnect`** hooks registered at bootstrap:

```dart
void registerMyFeatureState(AppStateSink state) {
  state.onWsReady((registrar, ref) { /* inbound handlers */ });

  state.onWsReconnect((connectionId, ref, send) async {
    // Re-send subscribe frames the server forgot on disconnect
    await send(
      type: 'subscribe',
      channel: 'demo/room',
      payload: {'room_id': 'demo'},
    );
  });
}
```

Track what to restore in **module state** (e.g. `wsDemoSubscriptionsProvider`). The server cleans room membership on disconnect; the client must subscribe again.

## WS Demo try-it

1. Login → WS Demo → **Connect both WS** → **Subscribe room (Dart)**
2. Restart Dart container or kill network briefly
3. Connection log shows `socket closed — scheduling reconnect`
4. After backoff, reconnect + hook re-sends subscribe

## Related

- [state-ws-routing-flow](state-ws-routing-flow.html) — inbound message routing
- [STATE_SYSTEM.md](../../../../03_Base/Flutter/STATE_SYSTEM.md) — tier 2 transport
- [WS_SYSTEM.md](../../../../03_Base/WS_SYSTEM.md) — server tiers + demo/room
