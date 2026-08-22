# Match Setting — Core Flow

**Status:** Partial — practice offline + quick/event/invite online done; gameplay still stub  
**Created:** 2026-07-26  
**Last Updated:** 2026-08-20

Related: [match-hot-state.md](match-hot-state.md) · [ws-matchmaking-modes.md](ws-matchmaking-modes.md) · [ws-invite-match.md](ws-invite-match.md) · [practice-offline-routing.md](practice-offline-routing.md) · [practice-match-v1.md](practice-match-v1.md) · [core-match-loop.md](core-match-loop.md) · [home-and-play-hub-flow.md](home-and-play-hub-flow.md) · [EXAMPLE_MODULE.md](../03_Base/EXAMPLE_MODULE.md) · [DART_STATE_SYSTEM.md](../03_Base/DART_STATE_SYSTEM.md) · [Flutter STATE_SYSTEM.md](../03_Base/Flutter/STATE_SYSTEM.md) · [Arcori GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

**Chart + plain English guide:** [match-setting-flow — diagram](../02_FlowCharts/charts/match_flow/match-setting-flow.html) · [guide](../02_FlowCharts/charts/match_flow/match-setting-flow.guide.html)

## Objective

Match pipeline from Play hub through shared match state and back to Play idle.

| Stage | Focus | Status |
|-------|--------|--------|
| **1** | Play screen → type select → orchestrator → idle | Done |
| **2** | Match hot state Flutter ↔ Dart + catalog freeze | Done ([match-hot-state.md](match-hot-state.md)) |
| **2b** | Practice Flutter-only + stub gameplay | Done |
| **2c** | quickStart / specialEvent matchmaking | Done ([ws-matchmaking-modes.md](ws-matchmaking-modes.md)) |
| **2d** | Invite Friend Match | Done ([ws-invite-match.md](ws-invite-match.md)) |
| Later | Match UI / celebration / summary / durable rewards | Open |

## Match types

| Code | Label | Live path |
|------|-------|-----------|
| `practice` | Practice | Flutter-only local |
| `quickStart` | Quick Start | Dart matchmaking → match room |
| `specialEvent` | Special Event | Dart matchmaking → match room |
| `invite` | Invite | Dart private lobby (2 humans, no AI fill) → match room |

## Phases

```text
idle → selectingType (modal) → typeSetup → inMatch → postMatch → idle
```

Cancel from type modal returns to idle. Online auth failures abort with OK modal (no stuck lobby).

---

## Stage 1 — Hub + stubs (done)

- [x] Active plan + master plan index + cross-links
- [x] Flutter `play` module: models, notifier, Play screen, type modal, routes, drawer
- [x] `AppPaths.play` + `module_registry` wiring
- [x] Smoke tests + match-setting flowchart

---

## Stage 2 — Match room SSOT (done)

**Detail:** [match-hot-state.md](match-hot-state.md).

- [x] Dart `match` module + Flutter mirror + catalog freeze
- [x] Practice offline routing + stub auto loop
- [x] quickStart / specialEvent matchmaking promote into match room

---

## Stage 2d — Invite (done)

**Detail:** [ws-invite-match.md](ws-invite-match.md).

- [x] Replace invite stub with host contacts + guest notification Accept
- [x] Promote into same match room SSOT (2 seats, no AI fill)

---

## Later

- Weighted slam / real turns / random first player
- Per-type setup UIs and economy checks
- Match screen / celebration / Match Summary / Play Again
- FastAPI durable rewards
- Home bottom sink Trove • PLAY • Market

## Files Modified

- See linked plans for file lists (`match-hot-state`, `ws-matchmaking-modes`, practice plans)

## Notes

- Type picker is a centered `AppModal` over Play (not a route).
- Hot path only for live matches: Dart in-memory — not Python match persistence yet.
