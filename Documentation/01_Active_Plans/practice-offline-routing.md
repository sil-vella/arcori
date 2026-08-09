# Practice Offline Routing (Flutter-only)

**Status:** Completed  
**Created:** 2026-08-08  
**Last Updated:** 2026-08-08

Related: [practice-match-v1.md](practice-match-v1.md) · [match-hot-state.md](match-hot-state.md) · [match-setting-core-flow.md](match-setting-core-flow.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Correct the practice path so **practice never uses Dart WS**. After mode select:

- **Practice** → Flutter-only local match: 1 human + 2 AI, local snapshot, existing match surface on local state.
- **Not practice** → room-creation stub only (no WS / no Dart match create yet).

Gameplay (weighted slam, AI turns, random first player) stays out of this phase.

## Flow

```text
Play → choose type
  Practice → loadout (human) → local MatchSnapshot (human + ai:seat_1 + ai:seat_2)
            → practice surface (local Slam / End) → postMatch stub → idle
  Other   → roomCreateStub (log only) → postMatch stub → idle
```

## Scope locks

- Human loadout modal kept; AI seats use fixed stub catalog ids
- No catalog freeze / FastAPI on practice path
- Dart `match` module remains for later online modes; Flutter practice does not call it
- Non-practice does not open the match surface

## Implementation

- [x] `MatchFlowNotifier`: practice → `_runPracticeLocal`; other → `_runRoomCreateStub`
- [x] `MatchSnapshotNotifier.startLocalPractice` / `localSlam` / `localEnd`
- [x] Practice surface wired to local notifier (no WS)
- [x] Play screen opens surface only for practice `inMatch`
- [x] Tests + docs

## Gaps (next)

- Weighted slam / random first player / AI auto-play
- Real room create / matchmaking on Dart
- Match Summary / FastAPI finalize

## Files modified

- `app_codebase/flutter_base_06/lib/modules/play/play_notifier.dart`
- `app_codebase/flutter_base_06/lib/modules/play/screens/play_screen.dart`
- `app_codebase/flutter_base_06/lib/modules/match/state/match_notifier.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/practice_match_surface.dart`
- `app_codebase/flutter_base_06/test/modules/play/play_notifier_test.dart`
- `app_codebase/flutter_base_06/test/modules/match/match_notifier_test.dart`
- `Documentation/01_Active_Plans/practice-offline-routing.md`
- `Documentation/01_Active_Plans/practice-match-v1.md`
- `Documentation/01_Active_Plans/match-hot-state.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
