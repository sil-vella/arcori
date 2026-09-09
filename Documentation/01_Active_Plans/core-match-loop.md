# Core Match Loop

**Status:** In Progress — Rematch invite wiring done; celebration / durable writers next  
**Created:** 2026-07-20  
**Last Updated:** 2026-09-09

Related: [home-and-play-hub-flow.md](home-and-play-hub-flow.md) · [match-setting-core-flow.md](match-setting-core-flow.md) · [match-hot-state.md](match-hot-state.md) · [ws-matchmaking-modes.md](ws-matchmaking-modes.md) · [ws-invite-match.md](ws-invite-match.md) · [arcori-standings-surface.md](arcori-standings-surface.md) · [Arcori GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

## Objective

Define the end-to-end match path from Play Hub through result celebration and Match Summary exit actions.

## Flow

```text
Play Hub
  → select mode
  → matchmaking / setup
  → match
  → post-match modal (keep ended snapshot)
  → Done / Play New (leave)
  → Rematch (online + other human): create_rematch invite → lobby → series matchId
```

## Runtime progress (not full loop)

| Step | Status |
|------|--------|
| Mode select | Done (`/play`) |
| Practice setup + stub match | Done |
| quickStart / specialEvent matchmaking + stub match end | Done |
| Invite matchmaking | Done — [ws-invite-match.md](ws-invite-match.md) |
| Stub match Arcori selection (weights) | Done — [stub-match-arcori-selection.md](stub-match-arcori-selection.md) |
| Post-match modal (summary + Done / Play New) | Done — hold snapshot until leave |
| Stub `POST /authuser/avari/match/finalize` | Done — no economy writers yet |
| Rematch (invite-notify + series matchIds) | Done — online; other humans notified when present; same prior AI reseated when no/partial humans |
| Celebration / mastery anims / daily / durable writers | Not started |

## Match Summary contents

- Victory / defeat and match statistics
- Gold Fragments earned
- Profile XP and Rank progress
- Mastery changes (circulating — not ownership)
- Daily Mission progress
- Daily Cache unlock
- Generation and Legacy updates (including mint → Trove when earned)

## Exit actions

After post-match the player chooses:

| Action | Destination |
|--------|-------------|
| **Rematch** | Host `POST …/create_rematch` → notify other humans (if any) → Dart invite lobby with `rematch` flags → new `matchId = {seriesId}_{NNN}`; prior Arcori/slammer + prior AI ids on promote. Disabled for Practice only. |
| **Play New** | Leave room → Quick Start pipeline from the top |
| **Done** | Leave room → idle (Play hub) |
| **Play Again** (future) | Rematchmaking same mode — not wired |
| **Home / Velora / Trove** | Spec exits — not wired this slice |

## Series / match ids

- Always `roomId === matchId`.
- First match of a series: normal `m_<hex>_<rand>`; `seriesId = matchId`, `seriesIndex = 1`.
- Rematch N: `matchId = {seriesId}_{NNN}` (zero-padded 3 digits); snapshot carries `seriesId` + `seriesIndex`.
- Hot-state only this slice (no Postgres series table yet).

## Implementation Steps

- [x] Mode select → practice / quick / event pipelines (stub end)
- [x] Invite pipeline — [ws-invite-match.md](ws-invite-match.md)
- [x] Post-match modal; hold ended snapshot; Done / Play New leave
- [x] Stub finalize endpoint + Flutter `AvariApiOutcome` soft-fail
- [x] Rematch = invite notify + series-suffixed matchIds + prior loadout hints
- [ ] Celebration / mastery anims / daily / mission / cache UI
- [ ] Durable reward writers (mastery, gold, Rank XP, mint)
- [ ] Home / Velora / Trove exits from summary
- [ ] Tournament / history UI sorting by series
- [ ] Durable `match_series_links` (or results) when finalize writers land

## Next Steps

Wire celebration anims + durable finalize writers. Tournament sorting / durable series table later.

## Notes

Practice mode: AI only, no progression / economy (GDD) — finalize returns `applied: false, reason: practice`. Random multiplayer costs 1 Gold Cap.
Post-match keeps the Flutter ended snapshot until Done / Play New / Rematch so Rematch can capture series + seats; Dart `match/leave` runs on those exits before the rematch lobby find.

Task Manager: skipped this turn — remote App Dev checklist sync was blocked by the environment approval gate; markdown plans/case study are updated. Re-sync App Dev card `32` when TM writes are allowed.
