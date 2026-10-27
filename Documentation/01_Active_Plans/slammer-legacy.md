# Slammer Legacy (personal mint)

**Status:** Shipped (core loop)  
**Created:** 2026-10-09  
**Last Updated:** 2026-10-27 (sweet spot is per player, saved on the slammer row)

Related: [legacy-preserve.md](legacy-preserve.md) · [slammer-recovery-and-recharge.md](slammer-recovery-and-recharge.md) · [mastery.md](mastery.md) · [museum-browse.md](museum-browse.md) · [home-and-play-hub-flow.md](home-and-play-hub-flow.md) · [Arcori GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

## Objective

Move **personal Legacy and physical mint** from Arcori onto **slammers**. Arcori stay the world’s collectible history. Slammers become the player’s personal history.

Fantasy line: **Master the Arcori. Learn your slammer. Leave your Legacy.**

## Split (shipped)

| Object | Job | Ladder |
|--------|-----|--------|
| **Arcori** | World history | Match mastery → close at `closureMilestone` → echo next gen (30%) → closed row readable in **Velora** only |
| **Slammer** | Player history | Sweet-spot mastery (`10 × flips × (0.55 + 0.45 × fit)`) → preserve offer → leader window → mint or lost → Museum + Trove; echo grants next `player_slammers` row |

## Sweet spot (server-only)

The live sweet spot is **per player**, rolled once when that slammer enters the collection and saved on `player_slammers.sweet_spot` (`hitTarget` + `powerBracket`). It is never rewritten. Catalog values are the roll bias: 50% keep that design's `hitTarget`, 25% each of the other two; the power band keeps the catalog width and shifts by up to ±0.15. Online Dart overlays the saved spot onto the frozen feel stats for that user (two players can share a design id and still differ). Clients never receive those keys. Practice has no fit bonus.

The only player-facing signal of a good hit is **slammer mastery gained** (a number). No target marker, band, or “sweet spot” label in the app.

The running total is on the Avari profile slammer row as `points/preservationRequirement` (same shape as Arcori chips). Tapping that row opens the catalog detail, the same screen as a profile Arcori. The post-match summary leads with the slammer face and that same running total, with this match’s gain under it. Flipped Arcori sit in columns; a tap opens that disc larger in the center.

On each online slam: `added = 10 × flipCount × (0.55 + 0.45 × preferenceFit)` (miss / zero flips → 0). A cold hit that still flips awards 5.5 per flip; a perfect fit awards 10 per flip. The fit curve is unchanged; the gain is ten times the old amount. Stored as a decimal on `player_slammers`.

## Arcori (close-only)

`on_mastery_progress` for non-slammer designs does **not** open a first offer, leader window, or mint.

At `closureMilestone`: close the generation, seed the next with `echo_mastery_seed` (30%, min 1, cap preserve−1). No Trove row, no Museum row, no Legacy Owner from an Arcori. Closed generations appear in Velora browse/detail (`closed=1` catalog index). Master / Generation Creator can show on that Velora detail.

`preservationRequirement` remains the echo cap only.

## Slammers (preserve pipeline)

Slammer mastery drives the existing phases, keyed by slammer design id:

- Racing until `preservationRequirement` (catalog `legacy` block; Genesis starters use 750 / closure 1000)
- First offer → leader window → minted or lost (timeout / `closureMilestone`)
- Both endings close that generation and seed the next at 30%; echo also inserts the next `player_slammers` row (charges policy copied)
- Mint seals a Legacy snapshot (owner, mastery, flips, matches, best slam, Legacy ID) on the closed generation; digital slammer stays usable
- Website fulfill only; fulfill must not use the old Arcori-only Trove path without granting the next slammer

Museum and Trove list **slammers only**.

## Attunement (future)

Attunement / Legacy Eligible usage gates beyond `preservationRequirement` remain a follow-on. The shipped bar for the preserve race is catalog `legacy.preservationRequirement`, fed only by fit × flips.

## Implementation checklist

- [x] Strip `hitTarget` / `powerBracket` from client payloads; practice has no fit bonus
- [x] Persist slammer mastery; finalize applies `10 × flips × (0.55 + 0.45 × fit)`
- [x] Arcori: close-only + echo; Velora closed browse path
- [x] Slammer: offer / window / lost / mint; echo grants `player_slammers`
- [x] Mint seals Legacy snapshot; Museum + Trove are slammer-only
- [x] Profile slammer row shows mastery (`points/reach`) and opens catalog detail
- [x] Post-match: slammer face + running total; flipped Arcori as tappable columns
- [ ] Attunement math and richer Legacy Eligible gates (optional challenge)
- [ ] QR / Legacy ID public record surface polish

## Current progress

**2026-10-14:** Core Slammer Legacy loop is in runtime (Python + Dart + Flutter). Docs and GDD aligned to shipped sinks (Velora for closed Arcori; Museum/Trove for slammers).

**2026-10-19:** Avari profile slammer row shows mastery next to the public feel stats. Tap opens the same catalog detail as a profile Arcori. Circulating Genesis slammers already appear in Velora (Genesis → Slammers); closed slammer generations stay out of that archive.

**2026-10-19:** Post-match summary shows the equipped slammer and its running mastery (`points/reach`), with this match’s gain underneath. Flipped Arcori are columns; tap one to open it larger in the center. Finalize now includes slammer `mintReach`, `color`, and `lottieUrl` on that change.

**2026-10-27:** Sweet spot is rolled once per owned slammer and stored on `player_slammers.sweet_spot`. Catalog hit/band is the bias only. Online resolve reads the saved spot. Existing rows were backfilled.

## Notes

- Monetization stays repeatable: one physical piece per mastered slammer generation.
- Payment rule unchanged: app never collects cards; website charges; server seals the record.

## Task Manager

App Dev checklist: Slammer Legacy (sweet-spot mastery; Arcori close → Velora; preserve on slammers). Profile slammer row shows mastery and opens catalog detail. Player sweet spot (roll once on collection entry) checked, with a note on the same card.
