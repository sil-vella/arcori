# Core Match Loop

**Status:** Spec — partial runtime exists (practice offline; quick/event online stub end)  
**Created:** 2026-07-20  
**Last Updated:** 2026-08-09

Related: [home-and-play-hub-flow.md](home-and-play-hub-flow.md) · [match-setting-core-flow.md](match-setting-core-flow.md) · [match-hot-state.md](match-hot-state.md) · [ws-matchmaking-modes.md](ws-matchmaking-modes.md) · [ws-invite-match.md](ws-invite-match.md) · [arcori-standings-surface.md](arcori-standings-surface.md) · [Arcori GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

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

## Runtime progress (not full loop)

| Step | Status |
|------|--------|
| Mode select | Done (`/play`) |
| Practice setup + stub match | Done |
| quickStart / specialEvent matchmaking + stub match end | Done |
| Invite matchmaking | **Next** — [ws-invite-match.md](ws-invite-match.md) |
| Celebration / Match Summary / durable rewards / Play Again | Not started |

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

- [x] Mode select → practice / quick / event pipelines (stub end)
- [ ] Invite pipeline — [ws-invite-match.md](ws-invite-match.md)
- [ ] Match runtime beyond stub (weighted slam + FastAPI durable rewards)
- [ ] Result celebration modal / screen
- [ ] Match Summary payload + UI (all fields above)
- [ ] Play Again → rematchmaking without Play Hub revisit
- [ ] Home / Velora / Trove exits

## Next Steps

Ship invite WS, then celebration / summary when economy modules are ready.

## Notes

Practice mode: AI only, no progression / economy (GDD). Random multiplayer costs 1 Gold Cap.
