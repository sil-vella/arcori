# WS Matchmaking (Quick Join + Special Event)

**Status:** Implemented (Invite deferred as Play stub)  
**Created:** 2026-08-09  
**Last Updated:** 2026-08-09

Related: [practice-offline-routing.md](practice-offline-routing.md) · [match-hot-state.md](match-hot-state.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Online **quickStart** and **specialEvent** share join-or-create lobby logic (5s / 3 seats / DB AI fill), then promote into the existing **match room SSOT** (`matchId` + RoomRegistry). **Invite** stays a Play stub (no WS).

Auth / config failures and lobby timeouts abort the Play run (idle + `errorMessage`) and show a centered **OK** modal — no sticky “Finding players…” shell.

## Flow

```text
Play → quickStart | specialEvent
  → matchmaking/find (queueKey from game type)
  → join open lobby OR create + 5s timer
  → full(3) OR timeout → AI sample → MatchLifecycle.startFromLobby
  → roomId = matchId, match/state
  → Flutter match surface (stub auto-end for caller) → postMatch stub → idle

Play → invite → roomCreateStub (log) → idle
Play → practice → offline (unchanged)
```

## Room SSOT

- Lobby: optional `lobby_<id>` membership for fan-out on `matchmaking/lobby`
- Live match: **only** `match` module + core RoomRegistry (`roomId === matchId`)

## Files

- Dart: `bin/modules/matchmaking/**`, `match/match_lifecycle_contract.dart`, `match_service.startFromLobby`
- FastAPI: `POST /service/players/ai/sample`
- Flutter: `lib/modules/matchmaking/**`, play_notifier online path

## Invite

Deferred — no invite WS channels in this phase.
