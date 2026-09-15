# Special event achievements (event-scoped unlocks)

**Status:** In Progress  
**Created:** 2026-09-14  
**Last Updated:** 2026-09-14

Related: [achievements.md](achievements.md) · [unlock-types.md](unlock-types.md) · [ws-matchmaking-modes.md](ws-matchmaking-modes.md) · [core-match-loop.md](core-match-loop.md)

## Objective

Special Event matches feed the **same** post-match achievement celebration pipeline (`animated_background` + View → Achievements). Unlock rules are **per event**: flip count and/or full Arcori roster cleared across one or many attempts.

## How it works (reuse existing pipeline)

1. Finalize online `specialEvent` with `eventId`
2. Accumulate `player_special_event_progress` (flips + unique flipped design ids)
3. Evaluate achievement types `event_flips` / `event_arcori_cleared`
4. Return `achievementsUnlocked[]` → existing Flutter unlock modals + CTA

No separate celebration UI.

## SSOT

### Events

See [special-events.md](special-events.md) for full JSON match-rules schema (v2). Roster for clear achievements: `achievement_hooks.roster_design_ids` / `design_ids`.

### Achievements

Same `achievements.json`:

| Type | Params | Meaning |
|------|--------|---------|
| `event_flips` | `event_id`, `min` | Cumulative flips in that event ≥ min |
| `event_arcori_cleared` | `event_id`, optional `design_ids` | All roster ids flipped (params override or event catalog) |

Stub rows: `evt_stub_v1_flips_5`, `evt_stub_v1_clear_roster` — both use View → achievements + `animated_background`.

## Persistence

`player_special_event_progress` — unique `(user_id, event_id)`; `flips`, `flipped_design_ids` (JSONB).

Migration: `018_special_event_progress`

## Client

Finalize sends `eventId` from snapshot `matchType.eventId` (fallback stub id for Special Event).

## Implementation

- [x] Event catalog loader
- [x] Progress model + migration + repo
- [x] Evaluators + loader validation
- [x] Finalize wire + stub achievements
- [x] Flutter `eventId` on finalize
- [ ] Apply Alembic `018` in target envs
- [ ] Real event art under `/catalog-media/achievements/evt_…`
