# Match Setting — Core Flow

**Status:** Stage 1 done — Stage 2 practice hot state implemented ([match-hot-state.md](match-hot-state.md))  
**Created:** 2026-07-26  
**Last Updated:** 2026-08-05

Related: [match-hot-state.md](match-hot-state.md) · [practice-match-v1.md](practice-match-v1.md) · [core-match-loop.md](core-match-loop.md) · [home-and-play-hub-flow.md](home-and-play-hub-flow.md) · [EXAMPLE_MODULE.md](../03_Base/EXAMPLE_MODULE.md) · [DART_STATE_SYSTEM.md](../03_Base/DART_STATE_SYSTEM.md) · [Flutter STATE_SYSTEM.md](../03_Base/Flutter/STATE_SYSTEM.md) · [Arcori GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

**Chart + plain English guide:** [match-setting-flow — diagram](../02_FlowCharts/charts/match_flow/match-setting-flow.html) · [guide](../02_FlowCharts/charts/match_flow/match-setting-flow.guide.html)

## Objective

Match pipeline from Play hub through shared match state and back to Play idle.

| Stage | Focus |
|-------|--------|
| **1** | Play screen → type select → orchestrator stubs → idle (done) |
| **2** | Match hot state Flutter ↔ Dart WS + catalog freeze (done — practice stub; see [match-hot-state.md](match-hot-state.md)) |
| Later | Per-type setup, match UI, post-match / FastAPI durable rewards |

## Match types

| Code | Label | GDD / earlier plan alias |
|------|-------|--------------------------|
| `practice` | Practice | Practice (AI, free) |
| `quickStart` | Quick Start | Random Match |
| `specialEvent` | Special Event | Event Match |
| `invite` | Invite | Friend Match |

## Phases

```text
idle → selectingType (modal) → typeSetup → inMatch → postMatch → idle
```

Cancel from type modal returns to idle. Stage 1 never leaves `/play`. Stage 2 fills `inMatch` with live Dart state; match surface UI may still be minimal until a later stage.

---

## Stage 1 — Hub + stubs (done)

### Implementation Steps

- [x] Active plan + master plan index + cross-links
- [x] Flutter `play` module: models, notifier stubs, Play screen, type modal, routes, drawer
- [x] `AppPaths.play` + `module_registry` wiring
- [x] Smoke: drawer → Play → type select → stubs → idle on Play (widget + notifier tests)
- [x] Flowchart: `charts/match_flow/match-setting-flow` (main nav **Match Flow**)

### Current Progress

Stage 1 complete: `/play` hub, match-type `AppModal`, stub pipeline returns to idle.

---

## Stage 2 — Complete match state (Flutter ↔ Dart) — done (practice stub)

**Detail SSOT:** [match-hot-state.md](match-hot-state.md).

**Delivered:** Dart `match` module + Flutter mirror + `POST /service/catalog/designs` freeze; `_runMatchSsot` runs create → end → leave when Dart WS + auth are configured.

### Scope (summary — see match-hot-state for full)

| In (done) | Out (later) |
|----|-------------|
| Dart `match` module + Flutter mirror + practice stub create | Real matchmaking / invite / event fill |
| Full wire snapshots; `callerUserId`, `arenaId`, `matchType` object, seats with `arcoriIds[]` + `slammerId` | Full match gameplay UI / celebration / summary |
| FastAPI `/service/catalog/designs` batch for Dart freeze at init | SharedPrefs catalog hydrate; mid-match catalog reload |
| Terminal `phase: ended` → Play continues to postMatch/idle | FastAPI durable rewards |

### Implementation Steps

Tracked and checked off in [match-hot-state.md](match-hot-state.md).

### Notes (Stage 2)

- Hot path only: Dart in-memory — not Python match persistence yet.
- Auth: WS authuser JWT; catalog freeze uses service tier.
- Player matching remains stubbed until a later plan.
- Open polish: Flutter `error_policy` mapping for `match/…` WS failures; optional Dart WS integration test.

---

## Later (not Stage 2)

- Per-type setup UIs and economy checks
- Match screen / celebration / Match Summary / Play Again
- FastAPI durable rewards
- Home bottom sink Trove • PLAY • Market

## Files Modified

- `Documentation/01_Active_Plans/match-setting-core-flow.md`
- `Documentation/01_Active_Plans/match-hot-state.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/01_Active_Plans/core-match-loop.md`
- `Documentation/01_Active_Plans/home-and-play-hub-flow.md`
- `Documentation/02_FlowCharts/charts/match_flow/match-setting-flow.*`
- `app_codebase/flutter_base_06/lib/core/navigation/app_paths.dart`
- `app_codebase/flutter_base_06/lib/modules/module_registry.dart`
- `app_codebase/flutter_base_06/lib/modules/play/**`

## Notes

- Type picker is a centered `AppModal` over Play (not a route).
- Stage 1: no route auth gate; no WS / API.
- Stage 2: Dart hot state over WS; orchestrator still ends on Play idle.
