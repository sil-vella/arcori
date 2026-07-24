# Returning Player Startup Flow

**Status:** Spec captured — not implemented  
**Created:** 2026-07-20  
**Last Updated:** 2026-07-20

Related: [first-time-player-flow.md](first-time-player-flow.md) · [home-and-play-hub-flow.md](home-and-play-hub-flow.md) · [NOTIFICATION_SYSTEM.md](../03_Base/NOTIFICATION_SYSTEM.md)

## Objective

Define and implement the cold-start path for players who already have an account: auto login, sync, overnight processing, then the startup notification queue before Home.

## Flow

```text
Splash
  → automatic login
  → account sync
  → process overnight changes
  → startup notification queue
  → Home
```

## Startup notification queue

The queue can include:

- Daily login reward
- Daily Missions progress
- Generation nearing closure
- Generation closed
- Legacy Preserved or Legacy Lost
- New event
- Friend / social activity
- Inbox
- Market updates

## Presentation rules

- Important **generation** or **event** news may appear as a **full-screen modal**.
- Other news appears in the **Home news feed** (see [home-and-play-hub-flow.md](home-and-play-hub-flow.md)).

## Implementation Steps

- [ ] Auto login + account sync on Splash
- [ ] Overnight change processor (generation / legacy / economy deltas)
- [ ] Ordered startup notification queue UI
- [ ] Full-screen modal path for critical generation/event news
- [ ] Defer non-critical items to Home World News feed
- [ ] Hand off to Home when queue is exhausted or dismissed

## Current Progress

Spec restored from Caps GDD drafts into this active plan.

## Next Steps

Map queue item types to notification / catalog / match domain events; align with existing notifications module where possible.

## Notes

GDD v0.4 Navigation (`Splash→Notifications→News→Daily Missions→Home`) is the short form of this returning path — this plan is the authoritative detail.
