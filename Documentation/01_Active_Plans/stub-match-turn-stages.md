# Stub Match Turn Stages

**Status:** Completed  
**Created:** 2026-08-21  
**Last Updated:** 2026-08-21

Related: [stub-match-arcori-selection.md](stub-match-arcori-selection.md) · [match-hot-state.md](match-hot-state.md) · [practice-stub-gameplay.md](practice-stub-gameplay.md) · [ws-matchmaking-modes.md](ws-matchmaking-modes.md)

## Objective

After seats + Arcori pick, run a **2-round × 1 slam per seat** auto stub loop on the online Dart match (and align practice slam `lastEvent`), using each seat’s existing `slammerId`. No player input, scoring, or physics yet.

## Flow

```text
startFromLobby (select Arcori + freeze)
  → broadcast phase=playing
  → MatchStubLoop: for round 1..roundsTotal (2):
       for each seat: match/action slam as seat.userId
  → endMatch (existing result stub)
  → Flutter waits for phase=ended (no client auto-end)
```

Practice stays Flutter-only; same `lastEvent` shape; AI seats use `stubSlammerId`.

## Shared slam lastEvent

```text
type, actorUserId, seatIndex, round, slammerId, arcoriId, result: stub, version
```

`slammerId` / `arcoriId` come from the actor seat (first `arcoriIds` entry if any).

## Implementation Steps

- [x] Enrich Dart `CoreActionPack._slam` lastEvent + round advance on wrap
- [x] `MatchStubLoop` after `startFromLobby`; then `endInternal`
- [x] Flutter: remove online `autoEndOnlineMatch`; wait for Dart `ended`
- [x] Practice: richer lastEvent + AI `stubSlammerId`
- [x] Dart / Flutter unit tests
- [x] Master plan + App Dev TM + Tech Spec / case study note

## Current Progress

Complete.

## Next Steps

Weighted slam / real turns / random first player (master plan).

## Files Modified

- Dart: `core_action_pack.dart`, `match_stub_loop.dart`, `match_service.dart`
- Flutter: `play_notifier.dart`, `match_notifier.dart`
- Tests: Dart match / matchmaking; Flutter `match_notifier_test.dart`
- Docs: this plan; master plan; Tech Spec; case study

## Notes

- Seats already carry `slammerId` from lobby / stub constant; this plan does not add match-time slammer pick.
- Stub loop cancels if match ends or is removed mid-run.
- Out of scope: player slam UI, weighted scoring, celebration / Match Summary.
- **Task Manager:** App Dev (`32`) checklist `146` (+ duplicate `147` from retry) marked done; note `148`. Do not delete `147` unless asked.

## Case study

Online stub now advances turn stages (2×N stub slams with seat slammer on `lastEvent`) before `endMatch`, instead of Flutter ending after ~400ms.
