# Match setting flow — plain English guide

This chart is the **Match Flow** home chart. Stage 1 is Flutter-only (Play hub → type select → stub pipeline → idle). Later stages add Dart hot match state and the rest of the stack under this same nav section.

## Concepts

| Piece | Role |
|-------|------|
| **PlayScreen** | Start and end hub. Stage 1 never navigates away. |
| **MatchFlowNotifier** | Owns `phase` + `selectedType` via `matchFlowProvider`. |
| **MatchType** | `practice`, `quickStart`, `specialEvent`, `invite`. |
| **AppModal** | Type picker overlay — not a go_router route. |
| **Stub hooks** | `_runTypeSetup`, `_runMatchSsot`, `_runPostMatch` — no-ops today; Stage 2 fills match state via Flutter ↔ Dart WS. |

### Phases

| Phase | What happens |
|-------|----------------|
| `idle` | Play button enabled; ready for a new run. |
| `selectingType` | Centered modal open; cancel returns to idle. |
| `typeSetup` | Per-type setup hook (stub). |
| `inMatch` | Shared gameplay SSOT hook (stub → live Dart state in Stage 2). |
| `postMatch` | Type-dependent post-match hook (stub). |

## Step-through

1. Open **Play** from the drawer (`AppPaths.play` → `/play`).
2. Press **Play** → `startPlay()` → `selectingType`.
3. Modal lists the four types. Close / barrier → `cancelSelection()` → `idle`.
4. Choose a type → `selectType(type)` → `typeSetup` → `inMatch` → `postMatch` → clear state → `idle`.
5. Play button is disabled while not idle; phase label shows on the screen.

Re-entrancy: `startPlay` is ignored unless idle. A `_runId` guard drops stale async work if selection is cancelled mid-flight (hooks are sync today).

## Copy-paste examples

Start selection from the screen:

```dart
final notifier = ref.read(matchFlowProvider.notifier);
notifier.startPlay();
final type = await showMatchTypeSelectModal(context);
if (type == null) {
  notifier.cancelSelection();
  return;
}
await notifier.selectType(type);
```

Phase enum (models):

```dart
enum MatchFlowPhase {
  idle,
  selectingType,
  typeSetup,
  inMatch,
  postMatch,
}
```

## Try it locally

1. Launch Flutter (`wfrun` / Chrome launch scripts).
2. Drawer → **Play**.
3. Press **Play**, pick a type — stubs finish immediately; you stay on Play idle.
4. Or run tests:

```bash
cd app_codebase/flutter_base_06
flutter test test/modules/play/
```

Dev traces: `play_notifier.dart` uses `LOGGING_SWITCH` + `customlog` for phase transitions (needs `DUTCH_DEV_LOG=1`).

## Related

- Active plan: [match-setting-core-flow.md](../../../01_Active_Plans/match-setting-core-flow.md)
- Broader loop (summary / exits): [core-match-loop.md](../../../01_Active_Plans/core-match-loop.md)
- Navigation: [NAVIGATION_SYSTEM.md](../../../03_Base/Flutter/NAVIGATION_SYSTEM.md)
- Modals: [MODAL_SYSTEM.md](../../../03_Base/Flutter/MODAL_SYSTEM.md)
- Example module (Stage 2 pattern): [EXAMPLE_MODULE.md](../../../03_Base/EXAMPLE_MODULE.md)
- State registration pattern: [state-module-registration-flow](../flutter/state/state-module-registration-flow.html)
