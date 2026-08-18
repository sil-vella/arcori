# WS Invite Match (Friend Match)

**Status:** Next — not started (Play stub today)  
**Created:** 2026-08-09  
**Last Updated:** 2026-08-18

Related: [ws-matchmaking-modes.md](ws-matchmaking-modes.md) · [match-hot-state.md](match-hot-state.md) · [match-setting-core-flow.md](match-setting-core-flow.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Replace the Play **invite** `roomCreateStub` with a real Friend Match path that still lands in the existing **match room SSOT** (`matchId` + RoomRegistry), without reusing Quick Join’s public queue.

## Current behavior

```text
Play → invite → _runRoomCreateStub (log only) → postMatch stub → idle
```

No Dart invite channels, no lobby, no match surface.

## Target (draft — confirm in impl)

```text
Play → invite → host creates private lobby / room code
  → guest joins by code (or future friends list)
  → start when ready (or host start) → MatchLifecycle.startFromLobby / startInvite
  → roomId = matchId, match/state → match surface → postMatch stub → idle
```

Exact host/guest UX, AI fill rules, and whether invite shares any matchmaking store keys with quickStart are **open** — decide before coding.

## Scope locks (proposed)

- Reuse match room SSOT from [match-hot-state.md](match-hot-state.md); do not invent a parallel room id
- Auth gate + OK modal pattern from [ws-matchmaking-modes.md](ws-matchmaking-modes.md)
- Practice stays Flutter-only; quickStart/specialEvent stay queue-based matchmaking
- No durable rewards / Match Summary in this plan

## Implementation steps

- [ ] Product decisions: code vs friends invite; seat count; AI fill if incomplete; who can start
- [ ] Dart: invite channels / store (create, join, cancel, start) + promote into `MatchLifecycle`
- [ ] Flutter: invite setup UI (replace stub) + lobby/waiting + errors via OK modal / policy
- [ ] Tests (Dart + Flutter) + flowchart update if flow charts change
- [ ] Master + related plans marked done when shipped

## Next steps

Start with product decisions, then Dart invite module aligned with existing matchmaking/match contracts.

## Notes

- GDD alias: Friend Match
- Prior art: `matchmaking` queueKey / lobby timer patterns — invite should not collide with `quickStart||` queues

## Task Manager

Track as an open checklist on **App Dev** (task `32`).
