# Match Setting — Core Flow

**Status:** Stage 1 done — Stage 2 detail in [match-hot-state.md](match-hot-state.md)  
**Created:** 2026-07-26  
**Last Updated:** 2026-08-05

Related: [match-hot-state.md](match-hot-state.md) · [core-match-loop.md](core-match-loop.md) · [home-and-play-hub-flow.md](home-and-play-hub-flow.md) · [EXAMPLE_MODULE.md](../03_Base/EXAMPLE_MODULE.md) · [DART_STATE_SYSTEM.md](../03_Base/DART_STATE_SYSTEM.md) · [Flutter STATE_SYSTEM.md](../03_Base/Flutter/STATE_SYSTEM.md) · [Arcori GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

**Chart + plain English guide:** [match-setting-flow — diagram](../02_FlowCharts/charts/match_flow/match-setting-flow.html) · [guide](../02_FlowCharts/charts/match_flow/match-setting-flow.guide.html)

## Objective

Match pipeline from Play hub through shared match state and back to Play idle.

| Stage | Focus |
|-------|--------|
| **1** | Play screen → type select → orchestrator stubs → idle (done) |
| **2** | Complete **match hot state**: Flutter client ↔ Dart backend over WS (next) |
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

## Stage 2 — Complete match state (Flutter ↔ Dart) — next

**Detail SSOT:** [match-hot-state.md](match-hot-state.md) (snapshot shape, caller/arena, catalog freeze via `/service/catalog`, matching stubbed).

**Goal:** Replace the `_runMatchSsot` stub with a real **module-owned hot match store** on the Dart backend, synced to Flutter over authuser WS — same pattern as [example_module](../03_Base/EXAMPLE_MODULE.md) (fork; do not extend it).

```text
PlayScreen / MatchFlowNotifier
  → WsConnectionManager (dart authuser)
  → match/* channels
  → Dart MatchStore (hot) + per-match catalog freeze
  → WS full snapshot → Flutter match notifier / replay
```

### Scope (summary — see match-hot-state for full)

| In | Out (later) |
|----|-------------|
| Dart `match` module + Flutter mirror + practice stub create | Real matchmaking / invite / event fill |
| Full wire snapshots; `callerUserId`, `arenaId`, `matchType` object, seats with `arcoriIds[]` + `slammerId` | Full match gameplay UI / celebration / summary |
| FastAPI `/service/catalog` batch for Dart freeze at init | SharedPrefs catalog hydrate; mid-match catalog reload |
| Terminal `phase: ended` → Play idle | FastAPI durable rewards |

### Implementation Steps

Tracked in [match-hot-state.md](match-hot-state.md) (A service catalog → B Dart module → C Flutter → D charts).

### Notes (Stage 2)

- Hot path only: Dart in-memory — not Python match persistence yet.
- Auth: WS authuser JWT; catalog freeze uses service tier. Align with [WS_SYSTEM.md](../03_Base/WS_SYSTEM.md).
- Player matching remains stubbed until a later plan.

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
