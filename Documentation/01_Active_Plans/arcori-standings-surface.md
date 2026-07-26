# Arcori Standings Surface

**Status:** Standings GET + Detail tab + wfrun tiger seed; My Mastery still open  
**Created:** 2026-07-24  
**Last Updated:** 2026-07-25

Related: [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md) · [Tech Spec](../Game_Specific/Arcori_Technical_Specification_v0.4.md) · [Content Bible](../Game_Specific/Arcori_Content_Bible_v0.4.md) · [catalog-hot-reload.md](catalog-hot-reload.md)

## Objective

Define Velora / Trove / Arcori Detail (Standings + My Mastery) and transport (HTTP + WS nudge).

## Semantics

- **Mastery** on circulating designs ≠ ownership.
- **Trove** = minted closed Arcori only (out of circulation).
- **Museum** = world history of closed generations (not personal Trove).
- Starter “Arcori” grants = play/mastery access, not mints.

## Surfaces

| Surface | Role |
|---------|------|
| Velora | World browse → Arcori Detail |
| Trove | Minted list only |
| Arcori Detail | SSOT; **Details** + **Standings** tabs (My Mastery deferred) |
| Sink | Trove • PLAY • Market (PLAY = circulating access) |

## Standings module (Postgres)

New module `bin/modules/standings/` — **not** catalog JSON.

| Piece | Role |
|-------|------|
| `design_standings` | Per `(internal_id, generation_number)` fill + leader window |
| `design_standings_ranks` | Synthetic rank labels + mastery points (no `user_id` yet) |
| `standings_service.replace_design_standings` / `clear_design_standings` | Internal apply (seed + future match) |
| `GET /authuser/standings/design?id=` | Authuser read; empty zeros/ranks if unset |

Response shape:

```text
{ internalId, generation: { number, roman }, fill: { current, cap },
  leaderWindowEndsAt, ranks: [{ rank, displayLabel, masteryPoints }] }
```

## Done

- Velora theme buttons → theme browse → Detail (circle art)
- Detail tabs: Details | Standings (HTTP on Standings tab enter)
- Catalog authuser APIs + `/catalog-media`
- wfrun: `automation/backend/seed_or_clear_standings.py` — prompt **seed** or **clear** for Tiger Genesis `ANM-TIG-GEN001-0001`

## Transport

HTTP on enter; optional WS `standings_changed` / mint invalidate while Detail open (deferred). No per-flip streams.

## Implementation Steps

- [x] Document already aligned in Game_Specific (this plan)
- [x] Catalog authuser APIs + `/catalog-media` + Flutter Velora browse / Detail shell
- [x] Standings module + GET + Detail Standings tab + wfrun tiger seed/clear
- [ ] REST my-mastery endpoints + Flutter My Mastery tab
- [ ] Match-driven apply; optional WS invalidate hooks
- [ ] Trove

## Notes

Full placement rationale lives in Cursor plan `live_arcori_stats_placement`.
