# Practice Match v1 (scaffold + loadout)

**Status:** Routing superseded by Flutter-only practice — see [practice-offline-routing.md](practice-offline-routing.md)  
**Created:** 2026-08-05  
**Last Updated:** 2026-08-09

Related: [practice-offline-routing.md](practice-offline-routing.md) · [practice-stub-gameplay.md](practice-stub-gameplay.md) · [ws-matchmaking-modes.md](ws-matchmaking-modes.md) · [ws-invite-match.md](ws-invite-match.md) · [match-hot-state.md](match-hot-state.md) · [match-setting-core-flow.md](match-setting-core-flow.md) · [core-match-loop.md](core-match-loop.md) · [00_MASTER_PLAN.md](00_MASTER_PLAN.md)

**Charts:** [match-setting-flow](../02_FlowCharts/charts/match_flow/match-setting-flow.html) · [match-state-flow](../02_FlowCharts/charts/dart_backend/state/match-state-flow.html)

## Objective

Playable **practice** loop: loadout → **local** Flutter match surface → auto stub slams → End → Play idle. Practice has **no subtype** and **does not use Dart WS**.

Dart action packs / `match/create` from the earlier scaffold remain in the codebase for **online modes**; they are **not** on the live practice path.

## Scope locks

- **Rules:** stub `slam` (`lastEvent` + rotate `active`); no weighted flip / score yet
- **Loadout:** pick 1 Arcori + 1 slammer for the human; AI seats: pool `userId` + empty loadout until gameplay; `arenaId` fixed (`arena_velora_plaza`)
- **Seats:** human + 2 AI from embedded pool

## Type / subtype

```json
{ "code": "practice" }
{ "code": "quickStart" }
{ "code": "specialEvent", "subtype": "royal-battle", "eventId": "…" }
```

Practice omits `subtype`. Online packs key by `(code, subtype)` when needed.

## Flow (current)

```text
Play → type Practice → loadout modal
  → Flutter local MatchSnapshot (3 seats)
  → full-screen readout + auto stub loop
  → postMatch stub → idle
```

Online types: [ws-matchmaking-modes.md](ws-matchmaking-modes.md). Invite: [ws-invite-match.md](ws-invite-match.md).

## Dart action packs (dormant for practice)

| Layer | Role |
|-------|------|
| **CoreActionPack** | Shared actions (`slam`) — used on online match path |
| **TypeSubtypePackRegistry** | Extra actions per `(code, subtype)` |
| **ActionDispatcher** | `match/action` → core then pack |

## Gaps (next)

- Weighted flip using freeze / local attributes
- AI auto-slam on its turn
- Random first player
- **Invite** — [ws-invite-match.md](ws-invite-match.md)
- Match Summary / FastAPI finalize

## Files modified

- See [practice-offline-routing.md](practice-offline-routing.md) for current Flutter routing files
- Earlier Dart scaffold: `app_codebase/dart_bkend_base_02/bin/modules/match/**`
