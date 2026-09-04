# Random first player

**Status:** Completed  
**Created:** 2026-09-04  
**Last Updated:** 2026-09-04

Related: [00_MASTER_PLAN.md](00_MASTER_PLAN.md) · [2d-slam-physics.md](2d-slam-physics.md) · [player-slam-input.md](player-slam-input.md)

## Objective

At match start (online + practice), pick a random seat to go first; keep that order for every round (wrap back to the same first seat).

## Implementation Steps

- [x] Snapshot field `firstSeatIndex` on wire + Dart/Flutter models
- [x] Pick random first seat in `createFromLobby` / practice start
- [x] Slam advance wraps relative to `firstSeatIndex` (not always seat 0)
- [x] Turn runner + practice turn loop iterate from `firstSeatIndex`
- [x] Tests + master plan / case study

## Current Progress

Completed. Online and practice matches pick `firstSeatIndex` uniformly at create; turn order is `(first + offset) % seatCount` each round.

## Next Steps

Celebration + Match Summary (master plan).

## Files Modified

- `app_codebase/dart_bkend_base_02/bin/modules/match/turn_order.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_models.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_store.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_service.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_turn_runner.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/core_action_pack.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_lifecycle_contract.dart`
- `app_codebase/dart_bkend_base_02/test/turn_order_test.dart`
- `app_codebase/flutter_base_06/lib/modules/match/input/turn_order.dart`
- `app_codebase/flutter_base_06/lib/modules/match/input/match_grace.dart`
- `app_codebase/flutter_base_06/lib/modules/match/state/match_snapshot_state.dart`
- `app_codebase/flutter_base_06/lib/modules/match/state/match_notifier.dart`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/Game_Specific/Arcori_Technical_Specification_v0.4.md`
- `Documentation/01_Active_Plans/03_CASE_STUDY.md`

## Notes

Seat indices stay fixed (join order); only **who acts first** is random. Tests may pass `firstSeatIndex: 0` for deterministic slam order.

## Case study

Recorded in [03_CASE_STUDY.md](03_CASE_STUDY.md) — random first seat + wrap order.

## Task Manager

App Dev (`32`): checklist **Weighted slam / real turns / random first player** (`127`) checked; note `117` updated; completion note `227`.
