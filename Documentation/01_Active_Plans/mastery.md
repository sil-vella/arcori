# Mastery (match deltas + access pool)

**Status:** In Progress — finalize writers + access sync live; My Mastery tab still open  
**Created:** 2026-09-11  
**Last Updated:** 2026-09-13

Related: [core-match-loop.md](core-match-loop.md) · [arcori-standings-surface.md](arcori-standings-surface.md) · [player-profile-schema.md](player-profile-schema.md) · [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md) · [Tech Spec](../Game_Specific/Arcori_Technical_Specification_v0.4.md)

## Objective

Lock post-match **mastery point deltas** per design, durable writers, **mastery-gated circulating access** (pool), and the player **Mastery Value** aggregate formula.

## Semantics

- Mastery is **circulating progress** on a design — **not ownership**.
- Stored on `player_mastery` per `(user, design, generation)` — **per player**, not global.
- Practice: **no mastery** (same skip as gold economy).
- **Playable pool** = `player_design_access` rows with mastery **> 0**.
- **+1 or more mastery on another player's design** → grant access (`source=mastery`) so it joins your pool.
- **0 mastery** → revoke access (leave collection / select pool), **except your own Kin**.
- **Own Kin (creator):** starts at **100** mastery; floor **100** (cannot drop below). Other players treat your Kin like any Arcori (+1/+2 other curve) and can lose it at 0.
- Starter grants (`source=starter`): **10 designs from Genesis/Pioneers** on profile create (guest/regular), each with **10** initial mastery + permanent starter slammer. Composition: **9** with `selectionWeight` in **[8.0, 10.0]**, **1** with **[3.0, 4.0]**. Foundations / Creation are excluded. Pioneers seeds are all weight **10.0** (common band). Pool still drops designs at mastery **< 1** (except own Kin). Existing starter rows below 10 are bumped to 10 on sync.

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

## selectionWeight (sole how-often / value signal)

`printedRarity` is **removed**. Every design has **`selectionWeight`**:

| End of scale | Value | Meaning |
|--------------|-------|---------|
| Rarest | **0.01** | Least often selected; most Mastery Value per point |
| Most common | **10.00** | Most often selected; least Mastery Value per point |

Same field for: match seat pick, Gatherer pick, Mastery Value. Match region multipliers still live in `04_selection_weights.json` (region only).

## Mastery Value (locked 2026-09-13)

```text
MasteryValue = Σ_i ( masteryPoints_i × (10.0 / selectionWeight_i) )
N            = circulating playable catalog count (Active; not SLM/KIN/slammer)
density      = MasteryValue / max(1, N)
```

| Label | Density |
|-------|---------|
| Fair | `< 0.5` |
| Notable | `0.5 – < 1.5` |
| Sought | `1.5 – < 4` |
| Coveted | `4 – < 10` |
| Exquisite | `10 – < 25` |
| Priceless | `≥ 25` |

| Rule | Detail |
|------|--------|
| Inputs | Every `player_mastery` row; design catalog `selectionWeight` |
| Clamp | `[0.01, 10.00]`; missing → **3.0** |
| N | Global static catalog via `count_circulating_playable_arcori` — not player pool |
| Profile | `mastery.masteryValue` (number) + `mastery.masteryValueLabel` |

Helpers: `mastery_value_label` / `compute_profile_mastery_value_label`.

## Implementation Steps

- [x] Lock own vs other curves in plan + GDD / Tech Spec / case study
- [x] Finalize writers: compute + persist `player_mastery` (+ return `masteryChanges`)
- [x] Ensure collection access rows have `masteryPoints` (+ DB rows)
- [x] Flutter finalize sends `playedDesignId` + `flipsByDesign`; post-match chips; inventory `M#`
- [x] Access sync: grant on other +mastery; revoke at 0; Kin creator floor 100; starter seed 1
- [x] Remove `printedRarity`; Mastery Value from `selectionWeight` only
- [x] Expose Mastery Value on profile (`mastery.masteryValue` + `masteryValueLabel` Fair→Priceless)
- [ ] Standings apply from real user mastery (replace synthetic ranks when ready)
- [ ] REST My Mastery + Arcori Detail tab

## Current Progress

Writers + access-pool sync live. `printedRarity` removed. Profile shows `mastery.masteryValue` and `mastery.masteryValueLabel` (density = Value / circulating N). Rank/XP is not used — Mastery Value replaces it.

## Next Steps

My Mastery Detail tab; Standings from real user FKs; profile Mastery Value field.

## Files Modified

- Catalog JSON (no `printedRarity`); `04_selection_weights.json` v2; deleted `03_printed_rarity.json`
- `catalog_select.py`, `catalog_service.py`, `catalog_loader.py`, `kin_genesis.py`, `mastery_economy.py`
- Flutter Velora models / Detail
- Docs: GDD, Tech Spec, case study

## Notes

- Points floor at **0** generally; own Kin floor **100**.
- Idempotency for duplicate `matchId` still deferred (same as gold finalize).
- Starting 10 designs are **starter** access (`source=starter`) — no separate product name.
