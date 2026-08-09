# Practice Match v1 (scaffold + loadout)

**Status:** Routing superseded by Flutter-only practice — see [practice-offline-routing.md](practice-offline-routing.md)  
**Created:** 2026-08-05  
**Last Updated:** 2026-08-08

Related: [practice-offline-routing.md](practice-offline-routing.md) · [match-hot-state.md](match-hot-state.md) · [match-setting-core-flow.md](match-setting-core-flow.md) · [core-match-loop.md](core-match-loop.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

**Charts:** [match-setting-flow](../02_FlowCharts/charts/match_flow/match-setting-flow.html) · [match-state-flow](../02_FlowCharts/charts/dart_backend/state/match-state-flow.html)

## Objective

Playable **practice** loop: loadout → **local** Flutter match surface → stub slam → End → Play idle. Practice has **no subtype** and **does not use Dart WS**.

Dart action packs / `match/create` from the earlier scaffold remain in the codebase for **future online modes**; they are **not** on the live practice path.

## Scope locks

- **Rules:** stub `slam` (`lastEvent` + rotate `active`); no weighted flip / score yet
- **Loadout:** pick 1 Arcori + 1 slammer for the human; AI seats use stub ids; `arenaId` fixed (`arena_velora_plaza`)
- **Seats:** human + `ai:seat_1` + `ai:seat_2`

## Type / subtype

```json
{ "code": "practice" }
{ "code": "quickStart", "subtype": "type1" }
{ "code": "specialEvent", "subtype": "royal-battle", "eventId": "…" }
```

Practice omits `subtype`. Future online packs key by `(code, subtype)`.

## Flow (current)

```text
Play → type Practice → loadout modal
  → Flutter local MatchSnapshot (3 seats)
  → full-screen surface (local Slam / End)
  → postMatch stub → idle
```

Non-practice types: room-creation stub only (no match UI). See [practice-offline-routing.md](practice-offline-routing.md).

## Dart action packs (dormant for practice)

| Layer | Role |
|-------|------|
| **CoreActionPack** | Shared actions (`slam`) — used when online match path is wired |
| **TypeSubtypePackRegistry** | Extra actions per `(code, subtype)` |
| **ActionDispatcher** | `match/action` → core then pack |

## Gaps (next)

- Weighted flip using freeze / local attributes
- AI auto-slam on its turn
- Random first player
- Online room create / Dart match path for non-practice
- Match Summary / FastAPI finalize

## Files modified

- See [practice-offline-routing.md](practice-offline-routing.md) for current Flutter routing files
- Earlier Dart scaffold: `app_codebase/dart_bkend_base_02/bin/modules/match/**`
