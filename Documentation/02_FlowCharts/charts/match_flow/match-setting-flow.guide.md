# Match setting flow — plain English guide

This chart is the **Match Flow** home chart. Play hub → type select → pipeline. **`_runMatchSsot`** talks to Dart match hot state when Dart WS + auth are configured; otherwise it no-ops (unit tests / offline).

## Concepts

| Piece | Role |
|-------|------|
| **PlayScreen** | Start and end hub; stays on `/play`. |
| **MatchFlowNotifier** | Owns `phase` + `selectedType` via `matchFlowProvider`. |
| **MatchType** | `practice`, `quickStart`, `specialEvent`, `invite`. |
| **AppModal** | Type picker overlay — not a go_router route. |
| **`_runMatchSsot`** | Connects Dart WS → `match/create` → `match/end` → `match/leave` (practice stub). |
| **matchSnapshotProvider** | Flutter mirror of full Dart snapshots (`match/*` prefix). |

### Phases

| Phase | What happens |
|-------|----------------|
| `idle` | Play button enabled; ready for a new run. |
| `selectingType` | Centered modal open; cancel returns to idle. |
| `typeSetup` | Per-type setup hook (still stub — matching later). |
| `inMatch` | Live Dart match SSOT when configured. |
| `postMatch` | Type-dependent post-match hook (stub). |

## Step-through

1. Open **Play** from the drawer (`/play`).
2. Press **Play** → type modal → pick a type.
3. `typeSetup` stub runs.
4. `inMatch`: if `ARCORI_DART_WS_URL` + access token exist, Flutter creates a practice match on Dart (catalog freeze), ends it, leaves; snapshot mirrored via `matchSnapshotProvider`.
5. `postMatch` stub → idle.

## Copy-paste examples

```dart
await manager.send('dart', type: 'event', channel: 'match/create', payload: {});
await manager.send('dart', type: 'event', channel: 'match/end', payload: {'matchId': id});
```

## Try it locally

```bash
cd app_codebase/flutter_base_06
flutter test test/modules/play/ test/modules/match/
```

With backends up and dart-defines set, Drawer → Play → pick Practice runs create/end against Dart.

## Related

- Active plan: [match-hot-state.md](../../../01_Active_Plans/match-hot-state.md)
- [match-setting-core-flow.md](../../../01_Active_Plans/match-setting-core-flow.md)
- [match-state-flow](../dart_backend/state/match-state-flow.html)
- [EXAMPLE_MODULE.md](../../../03_Base/EXAMPLE_MODULE.md)
