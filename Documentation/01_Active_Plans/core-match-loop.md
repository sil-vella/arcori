# Core Match Loop

**Status:** Spec captured — not implemented  
**Created:** 2026-07-20  
**Last Updated:** 2026-07-24

Related: [home-and-play-hub-flow.md](home-and-play-hub-flow.md) · [arcori-standings-surface.md](arcori-standings-surface.md) · [Arcori GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

## Objective

Define the end-to-end match path from Play Hub through result celebration and Match Summary exit actions.

## Flow

```text
Play Hub
  → select mode
  → matchmaking / setup
  → match
  → result celebration
  → Match Summary
```

## Match Summary contents

- Victory / defeat and match statistics
- Gold Fragments earned
- Profile XP and Rank progress
- Mastery changes (circulating — not ownership)
- Daily Mission progress
- Daily Cache unlock
- Generation and Legacy updates (including mint → Trove when earned)

## Exit actions

After Match Summary the player chooses:

| Action | Destination |
|--------|-------------|
| **Play Again** | Returns **directly to matchmaking** (same mode) — do not force menu traversal |
| **Home** | Home |
| **Velora** | World browse / Arcori Detail (e.g. Standings or My Mastery) |
| **Trove** | Only when a mint was just earned (or via sink anytime) |

## Implementation Steps

- [ ] Mode select → matchmaking / setup pipeline
- [ ] Match runtime (Dart hot path + FastAPI durable rewards)
- [ ] Result celebration modal / screen
- [ ] Match Summary payload + UI (all fields above)
- [ ] Play Again → rematchmaking without Play Hub revisit
- [ ] Home / Velora / Trove exits

## Current Progress

2026-07-24 aligned with mastery vs mint / Velora / Trove.

## Next Steps

Align summary fields with economy, mastery, daily systems, and generation/legacy services as those modules land.

## Notes

Practice mode: AI only, no progression / economy (GDD). Random multiplayer costs 1 Gold Cap.
