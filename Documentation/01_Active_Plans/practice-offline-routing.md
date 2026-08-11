# Practice Offline Routing (Flutter-only)

**Status:** Completed  
**Created:** 2026-08-08  
**Last Updated:** 2026-08-09

Related: [practice-stub-gameplay.md](practice-stub-gameplay.md) · [practice-match-v1.md](practice-match-v1.md) · [ws-matchmaking-modes.md](ws-matchmaking-modes.md) · [ws-invite-match.md](ws-invite-match.md) · [match-hot-state.md](match-hot-state.md) · [player-profile-schema.md](player-profile-schema.md) · [match-setting-core-flow.md](match-setting-core-flow.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Correct the practice path so **practice never uses Dart WS**. After mode select:

- **Practice** → Flutter-only local match: 1 human + 2 AI (from embedded pool), local snapshot, existing match surface on local state.
- **quickStart / specialEvent** → online matchmaking — [ws-matchmaking-modes.md](ws-matchmaking-modes.md) (**done**).
- **Invite** → Play stub until [ws-invite-match.md](ws-invite-match.md).

Gameplay (weighted slam, random first player) stays deferred — stub auto loop is in [practice-stub-gameplay.md](practice-stub-gameplay.md).

## Flow

```text
Play → choose type
  Practice → loadout (human) → pick 2 of 10 embedded AI userIds
            → local MatchSnapshot (human + 2 AI seats)
            → auto stub loop (2 rounds × 3 slams) → end
            → postMatch stub → idle
  quickStart | specialEvent → matchmaking (see ws-matchmaking-modes)
  Invite → roomCreateStub (log) → postMatch stub → idle  # until ws-invite-match
```

## Scope locks

- Human loadout modal kept
- **Practice AI pool:** 10 `userId`s hardcoded in Flutter (`practice_ai_pool.dart`); sampled once from `ai_players_500.json` at implement time. **No API/DB fetch** at runtime.
- Per match: client `Random` picks **2** distinct pool members
- AI seats: `userId` + in-match fields only (`seatIndex`, `kind`, `score`, `connected`); empty `arcoriIds` / `slammerId` until gameplay
- No catalog freeze / FastAPI on practice path
- Dart `match` module remains for later online modes; Flutter practice does not call it
- Non-practice does not use the practice local path (online types use Dart matchmaking / invite stub)
- Play screen opens match surface for practice **and** online `inMatch`

## Implementation

- [x] `MatchFlowNotifier`: practice → `_runPracticeLocal`; invite → `_runRoomCreateStub`; quick/event → online matchmaking
- [x] `MatchSnapshotNotifier.startLocalPractice` / `localSlam` / `localEnd`
- [x] Embedded `practiceAiPoolUserIds` + `pickPracticeAiUserIds`
- [x] Auto stub match loop — see [practice-stub-gameplay.md](practice-stub-gameplay.md)
- [x] Practice surface readout (no manual Slam/End)
- [x] Play screen opens surface for `inMatch` (practice + online)
- [x] Tests + docs

## Gaps (next)

- Weighted slam / random first player / real AI decisions
- **Invite WS** — [ws-invite-match.md](ws-invite-match.md)
- Match Summary / FastAPI finalize

## Files modified

- `app_codebase/flutter_base_06/lib/modules/match/practice_ai_pool.dart`
- `app_codebase/flutter_base_06/lib/modules/play/play_notifier.dart`
- `app_codebase/flutter_base_06/lib/modules/play/screens/play_screen.dart`
- `app_codebase/flutter_base_06/lib/modules/match/state/match_notifier.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/practice_match_surface.dart`
- `app_codebase/flutter_base_06/test/modules/play/play_notifier_test.dart`
- `app_codebase/flutter_base_06/test/modules/match/match_notifier_test.dart`
- `app_codebase/flutter_base_06/test/modules/match/practice_ai_pool_test.dart`
- `Documentation/01_Active_Plans/practice-offline-routing.md`
- `Documentation/01_Active_Plans/practice-match-v1.md`
- `Documentation/01_Active_Plans/match-hot-state.md`
- `Documentation/01_Active_Plans/player-profile-schema.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
