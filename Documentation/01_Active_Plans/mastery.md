# Mastery (match deltas + access pool)

**Status:** In Progress — finalize writers + access sync live; My Mastery tab still open  
**Created:** 2026-09-11  
**Last Updated:** 2026-09-12

Related: [core-match-loop.md](core-match-loop.md) · [arcori-standings-surface.md](arcori-standings-surface.md) · [player-profile-schema.md](player-profile-schema.md) · [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md) · [Tech Spec](../Game_Specific/Arcori_Technical_Specification_v0.4.md)

## Objective

Lock post-match **mastery point deltas** per design, durable writers, and **mastery-gated circulating access** (pool).

## Semantics

- Mastery is **circulating progress** on a design — **not ownership**.
- Stored on `player_mastery` per `(user, design, generation)` — **per player**, not global.
- Practice: **no mastery** (same skip as gold economy).
- **Playable pool** = `player_design_access` rows with mastery **> 0**.
- **+1 or more mastery on another player's design** → grant access (`source=mastery`) so it joins your pool.
- **0 mastery** → revoke access (leave collection / select pool), **except your own Kin**.
- **Own Kin (creator):** starts at **100** mastery; floor **100** (cannot drop below). Other players treat your Kin like any Arcori (+1/+2 other curve) and can lose it at 0.
- Starter grants (`source=starter`): **10 random Genesis/Pioneers** designs on profile create (guest/regular), each with **10** initial mastery + permanent starter slammer. Foundations is excluded from the starter pool. Pool still drops designs at mastery **< 1** (except own Kin). Existing starter rows below 10 are bumped to 10 on sync.

## Locked match curves (2026-09-11)

### Own played Arcori

| Seat flips | Mastery Δ |
|------------|-----------|
| 0 | **−1** |
| 1 | **0** |
| 2+ | **+2** |

### Other Arcori (incl. other players' Kin)

| Flips on that design | Mastery Δ |
|----------------------|-----------|
| 0 | **0** |
| 1 | **+1** |
| 2+ | **+2** |

## Implementation Steps

- [x] Lock own vs other curves in plan + GDD / Tech Spec / case study
- [x] Finalize writers: compute + persist `player_mastery` (+ return `masteryChanges`)
- [x] Ensure collection access rows have `masteryPoints` (+ DB rows)
- [x] Flutter finalize sends `playedDesignId` + `flipsByDesign`; post-match chips; inventory `M#`
- [x] Access sync: grant on other +mastery; revoke at 0; Kin creator floor 100; starter seed 1
- [ ] Standings apply from real user mastery (replace synthetic ranks when ready)
- [ ] REST My Mastery + Arcori Detail tab

## Current Progress

Writers + access-pool sync in `finalize_match` / profile GET / select. Claim Kin stamps mastery 100.

## Next Steps

My Mastery Detail tab; Standings from real user FKs.

## Files Modified

- `bin/modules/avari/mastery_economy.py`
- `bin/modules/avari/avari_repository.py`
- `bin/modules/avari/avari_service.py`
- Flutter `avari_*`, `play_notifier`, `post_match_modal`, `inventory_face_chip`
- Tests: `test_mastery_economy.py`, `test_finalize_match.py`, `test_claim_kin.py`

## Notes

- Points floor at **0** generally; own Kin floor **100**.
- Idempotency for duplicate `matchId` still deferred (same as gold finalize).
- Starting 10 designs are **starter** access (`source=starter`) — no separate product name.
