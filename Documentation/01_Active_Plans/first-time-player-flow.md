# First-Time Player Flow

**Status:** Spec captured — not implemented  
**Created:** 2026-07-20  
**Last Updated:** 2026-07-24

Related: [returning-player-startup-flow.md](returning-player-startup-flow.md) · [home-and-play-hub-flow.md](home-and-play-hub-flow.md) · [core-match-loop.md](core-match-loop.md) · [arcori-standings-surface.md](arcori-standings-surface.md) · [Arcori GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md) · catalog Kin data `bin/modules/catalog/data/02_kin.json`

## Objective

Define and implement the first-session onboarding path from Splash through Genesis creation, starter **play/mastery access**, guided practice, and feature intros into Home.

## Flow

```text
Splash
  → optional intro
  → account / sign-in
  → choose Kin subtheme
  → customize Kin Arcori
  → choose name
  → Genesis Arcori created
  → receive play/mastery access to 10 random circulating Arcori + permanent starter slammer
  → guided practice match
  → match summary
  → Velora intro
  → Trove intro (empty — mints only after closure)
  → Rank / Profile XP intro
  → Museum intro
  → Daily Missions
  → Home
```

## Design notes

- The **Kin Arcori** is effectively the player’s avatar, but in-world it is their personal **Genesis Arcori**.
- Starter grant: **play/mastery access** to 10 random **circulating** designs + **permanent starter slammer** — **not** Trove mints. Mastery ≠ ownership.
- Guided practice is AI-only (no economy / progression rewards per GDD).

## Implementation Steps

- [ ] Splash + optional intro screens
- [ ] Account / sign-in gate for first install
- [ ] Kin subtheme selection (catalog-backed)
- [ ] Kin Arcori customize + name → Genesis created
- [ ] Starter mastery-access grant (10 designs + starter slammer)
- [ ] Guided practice match + match summary handoff
- [ ] Velora, Trove, Rank/XP, Museum, Daily Missions intros
- [ ] Land on Home with sink Trove • PLAY • Market

## Current Progress

Spec restored from Caps GDD drafts; 2026-07-24 aligned with mastery vs mint / Velora / Trove.

## Next Steps

Wire Flutter route graph and auth/guest gates to this sequence; catalog module supplies Kin + Arcori defs.

## Notes

Supersedes the thin returning-path Navigation line for **first install only** — returning players use [returning-player-startup-flow.md](returning-player-startup-flow.md).
