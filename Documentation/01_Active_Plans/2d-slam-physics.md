# 2D Slam Physics (Forge2D)

**Status:** Completed  
**Created:** 2026-08-29  
**Last Updated:** 2026-08-29 (client sim replay + acting-player result modal)

Related: [arcori-slam-impact.md](arcori-slam-impact.md) · [player-slam-input.md](player-slam-input.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Replace discrete stack-walk flip math with a Dart-authoritative Forge2D (Box2D) side-view sim so Arcori discs collide mid-air and change trajectory/speed; Flutter replays sampled poses from `outcome.sim`.

## Implementation Steps

- [x] Add `forge2d: ^0.14.2` (pure Dart); bump Dart backend SDK to `^3.8.0`
- [x] `slam_physics_world.dart` — World, circles, ground, fixed 1/60, sampling, faceUp/tumble
- [x] Wire into `resolveSlam` + `outcome.sim` (Dart + Flutter practice mirror)
- [x] `ArcoriStackSurface` timeline replay; spring fallback
- [x] Determinism / collision / faceUp tests + tech-spec wire note
- [x] Bounded sim clock (prefer sim over impulse); `ValueKey` by match version
- [x] Acting-player non-blocking 3s slam-result `AppModal` (X + auto-close)

## Current Progress

Completed. Online and practice slam outcomes include `sim.frames` pose timelines. All clients replay `outcome.sim` on `ArcoriStackSurface` (bounded 0→1 clock, ~2.5s wall cap); spring impulse only if sim missing. Acting player sees a fire-and-forget 3s result modal (`FLIP`/`MISS`, flip count, score delta) without pausing the turn clock. Flip/score remain Dart SSOT (practice mirrors).

## Next Steps

Tune kick/restitution visually; later catalog per-piece mass/friction ([match-hot-state.md](match-hot-state.md) gap).

## Files Modified

- `app_codebase/dart_bkend_base_02/pubspec.yaml`
- `app_codebase/dart_bkend_base_02/bin/modules/match/slam_physics_world.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/slam_resolver.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/core_action_pack.dart`
- `app_codebase/dart_bkend_base_02/test/slam_resolver_test.dart`
- `app_codebase/flutter_base_06/pubspec.yaml`
- `app_codebase/flutter_base_06/lib/modules/match/input/slam_physics_world.dart`
- `app_codebase/flutter_base_06/lib/modules/match/input/slam_resolver.dart`
- `app_codebase/flutter_base_06/lib/modules/match/state/match_notifier.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/arcori_stack_surface.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/practice_match_surface.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/slam_result_modal.dart`
- `Documentation/Game_Specific/Arcori_Technical_Specification_v0.4.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`

## Notes

- Pinned **forge2d 0.14.x** (not 0.15 FFI / Dart 3.12+) for Docker-friendly pure Dart.
- Face-up: resting angle in up hemisphere **or** cumulative tumble ≥ ¾π.
- Soft miss floor `power < 0.02` unchanged (timeouts).
- Dev proof: `arcoriStack: sim replay start/complete` and `slamResultModal: show` in `global.log` when `LOGGING_SWITCH` + `DUTCH_DEV_LOG=1`.

## Case study

Recorded in [03_CASE_STUDY.md](03_CASE_STUDY.md) — slam physics SSOT + `outcome.sim` wire.

## Task Manager

Skipped this session — remote login/sync needs explicit approval for env credentials. Add/check App Dev checklist: **2D slam physics (Forge2D)** when syncing next.
