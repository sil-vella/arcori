# Special-match Arcori select (player choice)

**Status:** Spec / backlog  
**Created:** 2026-10-04  
**Last Updated:** 2026-10-04

Related: [active-window-arcori-play-selection.md](active-window-arcori-play-selection.md) · [special-events.md](special-events.md) · [stub-match-arcori-selection.md](stub-match-arcori-selection.md) · [mastery.md](mastery.md) · [core-match-loop.md](core-match-loop.md)

## Objective

Strengthen **progression feel** by letting players **choose which circulating Arcori they bring** into **special matches** (Special Events and other modes that opt in via JSON), instead of always relying on post-seat weighted auto-pick.

Quick Start / Invite stay **server auto-select** (case study: hostility pairs more often). This plan widens the existing SE `hard_pick` / `preferredId` path beyond Preservation Chase alone.

## Product rules (proposed)

1. **Opt-in per match type / event** — JSON flag (e.g. `arcori.hard_pick: true` + eligible `source` / filters). Default off for QS/Invite.
2. **Player picks before find** — one design from their eligible circulating access (event filters apply: windows, min mastery ratio, roster, etc.).
3. **Wire** — `arcoriIds` (+ `preferredId` validation in `select_for_seats`) same as Preservation Chase / high-mastery SE.
4. **Empty eligible set** — block join with clear UX; no silent fallback to random for hard-pick events.
5. **AI** — event-defined pool (global windows, circulation weights, roster); not required to mirror human picker UI.
6. **Seat uniqueness** unchanged.

## Out of scope (this plan)

- Player pick on Quick Start / Invite (keep weighted auto-pick)
- Changing mastery economy curves
- Medallion / visual tiers — see [mastery-medallion-visuals.md](mastery-medallion-visuals.md)

## Implementation steps

- [ ] Inventory current SE events with `hard_pick` / pickers; list which should gain player select by default
- [ ] Generalize Flutter pre-find picker (not only active-window / high-mastery modals) keyed off event JSON
- [ ] Confirm Dart + FastAPI `preferredId` / `arcoriIds` path for all hard-pick sources
- [ ] Play hub / Special Event entry: picker before lobby; cancel returns idle
- [ ] Tests: eligible pool, reject invalid preferredId, empty pool blocks
- [ ] Docs: special-events.md + case study decision when shipped

## Current progress

Spec only. Preservation Chase + high-mastery SE already ship hard-pick; this plan is the **general progression** follow-on.

## Next steps

1. Decide which live / upcoming events require player select (default: all `hard_pick: true`).
2. Unify picker UX on Play hub before queue.

## Notes

- Task Manager: App Dev checklist item `358` (+ note `360`).
- Complements auto-pick for normal online modes; does not reverse that decision.
