# Practice Stub Gameplay (full match loop)

**Status:** Completed  
**Created:** 2026-08-09  
**Last Updated:** 2026-08-09

Related: [practice-offline-routing.md](practice-offline-routing.md) · [practice-match-v1.md](practice-match-v1.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Auto-run the full offline practice match with **stub slams only**:

- Round 1: each of 3 seats (human + 2 AI) gets 1 stub slam
- Round 2: each seat gets 1 stub slam again
- Then end → postMatch stub → idle

No weighted flip, score physics, or manual Slam/End.

## Flow

```text
startLocalPractice
  → runLocalPracticeStubMatch
      round 1: seat0, seat1, seat2 stub slam
      round 2: seat0, seat1, seat2 stub slam
      → localEnd
  → postMatch stub → idle
```

## Scope locks

- Flutter-only; no Dart WS / FastAPI
- Fixed turn order seat 0 → 1 → 2; start human
- ~200ms step delay (0 in tests via `practiceStubStepDelay`)
- Surface is readout-only (dismisses on ended)

## Implementation

- [x] `MatchSnapshotNotifier.runLocalPracticeStubMatch`
- [x] `MatchFlowNotifier._runPracticeLocal` awaits auto stub loop
- [x] Practice surface without Slam/End buttons
- [x] Tests + docs

## Gaps (next)

- Weighted slam / score
- Random first player
- Distinct AI decisions
- Match Summary / FastAPI finalize

## Files modified

- `app_codebase/flutter_base_06/lib/modules/match/state/match_notifier.dart`
- `app_codebase/flutter_base_06/lib/modules/play/play_notifier.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/practice_match_surface.dart`
- `app_codebase/flutter_base_06/test/modules/match/match_notifier_test.dart`
- `app_codebase/flutter_base_06/test/modules/play/play_notifier_test.dart`
- `Documentation/01_Active_Plans/practice-stub-gameplay.md`
- `Documentation/01_Active_Plans/practice-offline-routing.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
