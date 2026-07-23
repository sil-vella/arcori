# arcori — Dart backend state system

Infrastructure for **tiered state** in `dart_bkend_base_02`. Domain state lives in **modules** — see [EXAMPLE_MODULE.md](EXAMPLE_MODULE.md) for the cross-stack reference.

**Chart:** [backend-state-split](../02_FlowCharts/charts/base/backend-state-split.html)

Related: [WS_SYSTEM.md](WS_SYSTEM.md) · [PYTHON_STATE_SYSTEM.md](PYTHON_STATE_SYSTEM.md)

## Tiers

| Tier | Component | Lifetime |
|------|-----------|----------|
| 1 — Session | `WsConnectionContext.userId`, JWT verify | Per WS connection |
| 2 — Transport | `ConnectionRegistry`, WS dispatcher | Per connection |
| 3 — Domain | Module-owned stores (e.g. `ExampleModuleStore`) | Process / module reset |
| 4 — Ephemeral | Handler locals | Function scope |

## Core layout (transport only)

```
dart_bkend_base_02/bin/core/state/
  connection_registry.dart   Outbound send per connectionId
  room/room_registry.dart    roomId ↔ connectionId membership
  room/broadcast_hub.dart    Fan-out via connectionRegistry
  contracts/                 RoomMembershipContract, RoomBroadcasterContract
  state_registry.dart        resetStateRegistry() on handler rebuild
```

Feature modules (e.g. future game) use `roomBroadcaster` + `roomRegistry` from `state_registry.dart` — domain stores stay in the module.

## Bootstrap

[`module_registry.dart`](../../app_codebase/dart_bkend_base_02/bin/modules/module_registry.dart):

- `registerApplicationState()` → `resetStateRegistry()` + module resets (e.g. `resetExampleModuleState()`)
- `registerApplicationWsChannels()` → demo + module channels

## Reference module

[`modules/example_module/`](../../app_codebase/dart_bkend_base_02/bin/modules/example_module/):

| File | Role |
|------|------|
| `example_store.dart` | In-memory snapshot |
| `example_ws_service.dart` | `example/state` handler |
| `example_service.dart` | Optional FastAPI record |
| `example_app.dart` | WS registration |

## Add state to a new module

1. Create `modules/your_feature/` with module-owned store + WS handlers.
2. Register channels in `your_feature_app.dart`.
3. Call `resetYourFeatureState()` from `registerApplicationState()` if needed.
4. Optional: `FastApiServiceClient` for service-tier calls to Python.

## Tests

`dart test` — includes `example_module_store_test.dart`, `example_module_ws_test.dart`.

## Future

- Redis pub/sub layer on top of `BroadcastHub` (multi-instance WS)
- Game/match channels — add in a **product module** using core room contracts
