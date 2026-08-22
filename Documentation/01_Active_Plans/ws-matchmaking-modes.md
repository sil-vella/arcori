# WS Matchmaking (Quick Join + Special Event)

**Status:** Completed  
**Created:** 2026-08-09  
**Last Updated:** 2026-08-09

Related: [ws-invite-match.md](ws-invite-match.md) · [practice-offline-routing.md](practice-offline-routing.md) · [match-hot-state.md](match-hot-state.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

## Objective

Online **quickStart** and **specialEvent** share join-or-create lobby logic (5s / 3 seats / DB AI fill), then promote into the existing **match room SSOT** (`matchId` + RoomRegistry).

## Flow

```text
Play → quickStart | specialEvent
  → gate: auth + Dart WS URL (else OK modal abort)
  → matchmaking/find (queueKey from game type)
  → join open lobby OR create + 5s timer
  → full(3) OR timeout → AI sample → MatchLifecycle.startFromLobby
  → roomId = matchId, match/state
  → Flutter match surface (stub auto-end for caller) → postMatch stub → idle

Play → practice → offline (unchanged)
Play → invite → [ws-invite-match.md](ws-invite-match.md) (private 2-seat lobby, notification Accept)
```

## Room SSOT

- Lobby: optional `lobby_<id>` membership for fan-out on `matchmaking/lobby`
- Live match: **only** `match` module + core RoomRegistry (`roomId === matchId`)

## Implementation

- [x] Dart `matchmaking` module: find / join-or-create / 5s timer / promote
- [x] `MatchLifecycleContract` + `MatchService.startFromLobby` + catalog freeze + room subscribe
- [x] FastAPI `POST /service/players/ai/sample`
- [x] Flutter: wire quickStart / specialEvent → find; lobby modal; match surface
- [x] Auth / config / lobby-timeout abort → idle + centered OK modal (no sticky Finding players)
- [x] Lobby dismiss race (promote before mount / leave typeSetup) + match-surface single dismiss
- [x] Invite left as a separate plan — [ws-invite-match.md](ws-invite-match.md) (**done**)
- [x] Unit tests (Dart matchmaking + Flutter play gate) + active plans

## Gaps (deferred — not this plan)

- Weighted slam / real online gameplay loop
- Standing empty rooms
- Flutter `error_policy` mapping for all `matchmaking/…` WS codes

## Files

- Dart: `bin/modules/matchmaking/**`, `match/match_lifecycle_contract.dart`, `match_service.startFromLobby`
- FastAPI: `modules/players/**` (`POST /service/players/ai/sample`)
- Flutter: `lib/modules/matchmaking/**`, `play_notifier` online path, `play_failure_modal`, lobby + match surface dismiss hardening
- Docs: this file · [ws-invite-match.md](ws-invite-match.md) · master index

## Notes

- Verified manually: authenticated Quick Start → AI fill → promote → stub end → idle
- AI ids come from DB sample (not practice’s embedded 10-user pool)
