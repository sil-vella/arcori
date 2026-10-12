# Slammer Legacy (personal mint)

**Status:** Spec / direction locked — not built  
**Created:** 2026-10-09  
**Last Updated:** 2026-10-09 (generation echo uses the Arcori seed)

Related: [legacy-preserve.md](legacy-preserve.md) · [slammer-recovery-and-recharge.md](slammer-recovery-and-recharge.md) · [mastery.md](mastery.md) · [museum-browse.md](museum-browse.md) · [home-and-play-hub-flow.md](home-and-play-hub-flow.md) · [Arcori GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

## Objective

Move **personal Legacy and physical mint** from Arcori onto **slammers**. Arcori stay the world’s collectible history. Slammers become the player’s personal history.

Fantasy line: **Master the Arcori. Learn your slammer. Leave your Legacy.**

## Split

| Object | Job | Ladder |
|--------|-----|--------|
| **Arcori** | World history | Mastery → Generation → Closure → Museum |
| **Slammer** | Player history | Within a generation: Attunement → Slammer Mastery → Legacy → Physical Mint. On close: same next-gen mastery seed as Arcori |

Arcori keep circulating Mastery, generations, Museum records, **Master**, **Generation Creator**, and generation closure. That progression does **not** depend on a physical-mint purchase.

A slammer is something the player uses for hundreds of matches, learns (hit area, ideal strength), masters, and may later preserve as a physical piece of **that** slammer — not generic merchandise.

## Slammer lifecycle

```text
Acquire → Learn → Attune → Master → Legacy → Mint
```

| Stage | Meaning |
|-------|---------|
| **Acquire** | Own the slammer (starter, Market, later grants) |
| **Learn** | Play it; discover its hit area and ideal strength |
| **Attune** | Fill attunement toward **100%** |
| **Master** | Reach that slammer’s **Slammer Mastery** requirement (**Mastered**) |
| **Legacy** | **Legacy Eligible** only after Mastered **plus** a usage achievement — then **Legacy Available** |
| **Mint** | Player chooses to physically mint **this** mastered slammer |

**Mastered and Legacy are different.** Filling the mastery bar is not enough to mint.

**Legacy Eligible** (all required; exact thresholds TBD):

- 100% Attunement
- Full Slammer Mastery
- X successful flips
- X matches
- Optional: one special Mastery challenge

Then the slammer is **Legacy Available**. The player may keep using it with no mint, or mint it. Legacy stays rare.

## Mint seals the record; it does not retire the slammer

Physical mint **freezes** the Legacy snapshot. The digital slammer stays equipped and playable and becomes a **Legacy Slammer**.

Frozen example:

- Legacy established at 812 Mastery
- 4,291 flips
- 731 matches

Later play shows as **Post-Legacy** stats and does not rewrite that snapshot. Minting is desirable, not a loss of the favorite tool. (Arcori retirement still fits generations. Slammer retirement does not.)

## Next generation (same mastery seed as Arcori)

Slammer lines have generations. When a **slammer** generation closes, mastery moves forward the same way Arcori already do (`echo_mastery_seed` in `mastery_economy.py`). This is not a new formula.

| Rule | Behavior |
|------|----------|
| Closed generation | That generation’s mastery row stays as it was. It is not deleted or reduced. |
| Who receives the next gen | Every player with mastery **> 0** on the closed slammer generation |
| Next-gen mastery | `floor(closed × 0.30)`, at least **1**, never above `preservationRequirement − 1` |
| Zero on the closed gen | No next-gen seed |

Example: 750 on Void I → Void II starts at **225** (30%). A player at 2 starts the next gen at **1**. The cap stops the seed itself from counting as a full preserve bar.

Attunement and Legacy usage counters are not part of this seed. Only mastery carries, matching Arcori.

A minted Legacy snapshot stays on the generation that was sealed. The next generation is a new learn / attune / master cycle and does not rewrite that record. The player still has the digital slammer.

## What the physical piece carries

The minted object is that player’s slammer, with its history, plus a unique **QR / Legacy ID** that opens the digital record.

Example face:

- VOID SLAMMER
- Owner: Silvester
- Mastered: 18 March 2027
- Matches: 684
- Successful Slams: 1,921
- Arcori Flipped: 3,488
- Best Slam: 6 Arcori
- Attunement: 100%
- Mastery: 750 / 750

Offer copy is the story, not a shop banner: the player mastered it, learned every part, and can preserve that Legacy. Show the physical piece. Several slammers can each reach this, so the collection repeats.

Profile / Trove target — **My Legacy Slammers**:

- Starter — Minted
- Ember — Minted
- Void — Mastered
- Prism — 78%
- Stone Drop — 31%

## Arcori after the split

Museum is the history of Velora’s Arcori. Example:

- MUSHROOM I
- Generation I
- Master: Player X
- Highest Mastery: 612
- Closed: 2027
- Generation II created by Player X

Series `preservationRequirement` / `closureMilestone` stay **generation closure** numbers (Museum, Masters, Generation Creators). They are not the reason to sell a physical Arcori.

**Shipped today (do not treat as the new target):** Arcori preserve still offers a website physical mint into Trove, with Legacy Owner, echo generation, and Lost/Preserved. That loop stays in code until a follow-on retires the Arcori physical offer. New mint work follows this plan. See [legacy-preserve.md](legacy-preserve.md).

## Trove

**Target:** Trove (profile) lists **Legacy Slammers** — tools this Avari mastered and preserved.

**Today:** `/trove` still lists minted closed Arcori. Do not add new Arcori-mint UX on top of that.

## Out of scope (this plan)

- Implementing attunement math, slammer mastery writers, or checkout
- Changing Arcori match mastery curves
- Retiring the live Arcori preserve module in the same change as this spec
- Slammer `recovery` combat stat — [slammer-recovery-and-recharge.md](slammer-recovery-and-recharge.md)

## Implementation steps

- [ ] Lock numeric gates (attunement, slammer mastery cap, flips, matches, optional challenge)
- [ ] Persist per-slammer attunement, slammer mastery, usage counters, legacy snapshot, post-legacy counters
- [ ] On slammer generation close, seed next-gen mastery with `echo_mastery_seed` (closed row kept; 30%, min 1, cap preserve−1)
- [ ] Profile / Trove: My Legacy Slammers states (progress, Mastered, Legacy Available, Minted)
- [ ] Legacy Available offer → existing external checkout pattern (no card data in-app); fulfill seals snapshot and marks Legacy Slammer; digital slammer stays usable
- [ ] QR / Legacy ID → digital record
- [ ] Stop new Arcori physical-mint product work; later remove or repurpose the Arcori preserve purchase
- [ ] Case study + GDD already point here; update again when thresholds lock

## Current progress

Direction locked 2026-10-09. No runtime yet. Attunement and Slammer Mastery are not the catalog `hitTarget` / `powerBracket` feel stats and not Arcori `player_mastery`.

**2026-10-09:** a closed slammer generation hands players the next generation with the live Arcori echo seed (`floor(closed × 0.30)`, min 1, cap `preservationRequirement − 1`). Closed mastery stays.

## Next steps

Agree the Legacy Eligible gates, then a persistence sketch. Do not start checkout until those gates are numbers.

## Notes

- Monetization is repeatable: one physical piece per mastered slammer, each with its own frozen history.
- Payment rule unchanged from Arcori preserve: the app never collects cards; the website charges; the server is the only writer of the sealed record.

## Case study

[03_CASE_STUDY.md](03_CASE_STUDY.md) — vocabulary + major decision “Personal Legacy is the slammer” (2026-10-09). No HTML case study file in this repo.

## Task Manager

App Dev checklist: Slammer Legacy (personal mint; Arcori stay world history).
