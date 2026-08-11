# Home and Play Hub Flow

**Status:** Spec captured — not implemented  
**Created:** 2026-07-20  
**Last Updated:** 2026-07-24

Related: [returning-player-startup-flow.md](returning-player-startup-flow.md) · [core-match-loop.md](core-match-loop.md) · [match-setting-core-flow.md](match-setting-core-flow.md) · [first-time-player-flow.md](first-time-player-flow.md) · [arcori-standings-surface.md](arcori-standings-surface.md) · Flutter bottom-nav docs in `03_Base/Flutter/`

Stage 1 Play route + type select (drawer entry; Home sink later): [match-setting-core-flow.md](match-setting-core-flow.md).  
Play modes live status: practice / quick / event online stub — invite next [ws-invite-match.md](ws-invite-match.md).

## Objective

Define Home layout, Velora world entry, bottom sink, and the Play Hub modes that start a match.

## Home contents

Home contains:

- Player status and Rank progress
- Main Play card
- Entry into **Velora** (world browse)
- Daily Missions
- Featured generation or event
- World News feed
- Recently progressed Arcori (mastery — not ownership)

## Bottom sink

```text
Trove — PLAY — Market
```

- **Trove** — minted closed Arcori only.
- **PLAY** — circulating mastery-accessible designs.
- **Velora** — first-class from Home (and related), not under Trove.

## Play Hub

**PLAY** opens the Play Hub:

- Random Match
- Event Match
- Practice
- Friend Match
- Future modes

## Implementation Steps

- [ ] Home screen composition (status, Play, Velora, missions, featured, news, recent)
- [ ] Bottom sink: Trove • PLAY • Market (platform shell)
- [ ] Play Hub screen with mode list
- [ ] Wire each mode into [core-match-loop.md](core-match-loop.md) entry
- [ ] World News feed consumes deferred startup / overnight items

## Current Progress

2026-07-24 aligned with GDD Velora / Trove / mastery semantics.

## Next Steps

Implement Home + Play Hub Flutter screens against bottom-nav registration patterns; keep PLAY as the center sink action.

## Notes

Critical generation/event news may interrupt as full-screen modals (startup or on Home); routine items stay in World News.
