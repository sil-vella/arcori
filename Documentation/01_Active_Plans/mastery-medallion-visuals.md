# Mastery medallion visuals (per-player)

**Status:** Spec / backlog  
**Created:** 2026-10-04  
**Last Updated:** 2026-10-04

Related: [mastery.md](mastery.md) · [inventory-slammer-and-disc-art.md](inventory-slammer-and-disc-art.md) · [avari-profile.md](avari-profile.md) · [catalog-db-gen-serial.md](catalog-db-gen-serial.md) · [ui-visual-refactor.md](ui-visual-refactor.md)

## Objective

Add **visible progression** on owned / accessed Arcori: the **design identity stays the same** (name, face art, catalog id), but each player’s **medallion** (rim / frame / material tier) changes as **their** mastery on that design rises.

Different players looking at the same design can see different medallion tiers based on **their** mastery points (or mint-reach ratio). Catalog face Lottie/webp remains shared; only the medallion chrome is personal.

## Product rules (proposed)

1. **Design unchanged** — serial, face media, color accent from catalog / Kin bake stay the identity.
2. **Medallion is personal** — tier derived from that viewer’s (or seat owner’s) mastery on the design, not a global design field.
3. **Tier ladder** — discrete bands (exact thresholds TBD; e.g. by mastery points or `mastery / mintReach`). Art: rim / metal / glow variants, not new character art.
4. **Where it shows** — Avari inventory chips, match stack discs (seat owner’s tier), Velora detail when viewing **your** mastery, profile/Kin surfaces. Opponent discs use **their** tier when known from freeze/snapshot.
5. **Match freeze** — stamp a small `medallionTier` (or equivalent) per seat piece so clients do not re-derive mid-match from live mastery.
6. **No economy change** — visuals only; mastery writers unchanged.

## Open design questions

- Exact tier count and thresholds (align with Mastery Value labels vs mint-reach %?)
- Shared asset pack vs theme-tinted procedural rim
- Do Trove / closed-gen echoes show medallion at freeze-time mastery or current?

## Out of scope

- New character art per mastery band
- Player Arcori pick for QS/Invite — see [special-match-arcori-select.md](special-match-arcori-select.md)
- Changing selection weights by medallion tier

## Implementation steps

- [ ] Lock tier table (thresholds + labels) with design
- [ ] Author medallion rim assets / shader tokens (dark chrome compatible)
- [ ] Client helper: mastery → tier; wire `InventoryFaceChip` / `ArcoriCylinder`
- [ ] Match snapshot: include per-piece medallion tier at freeze
- [ ] Avari + Velora “your mastery” surfaces
- [ ] Tests: tier boundaries; snapshot parse; no catalog mutation
- [ ] Docs: mastery.md + case study when shipped

## Current progress

Spec only — idea captured for progression feel.

## Next steps

1. Agree tier count + art direction with UI visual refactor.
2. Prototype rim swap on Avari chips before match freeze work.

## Notes

- Task Manager: App Dev checklist item `359` (+ note `360`).
- Face media SSOT stays catalog; medallion is a presentation layer on player mastery.
