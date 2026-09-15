# Special events (JSON-driven match rules)

**Status:** In Progress  
**Created:** 2026-09-14  
**Last Updated:** 2026-09-14

Related: [special-event-achievements.md](special-event-achievements.md) · [core-match-loop.md](core-match-loop.md) · [ws-matchmaking-modes.md](ws-matchmaking-modes.md) · [achievements.md](achievements.md)

## Objective

Author each Special Event **entirely in JSON** (`special_events.json`): lobby size, AI fill, rounds, multi-match quota, Arcori source/filters, arena/region, media, eligibility (mastery / slammer), and fee. Matches are **open queue** (like Quick Start) with per-user progress `2/3` — not sticky rooms.

## SSOT

`app_codebase/python_base_05/bin/modules/special_events/data/special_events.json` (`schema_version: 2`)

| Block | Role |
|-------|------|
| `matchmaking` | `players`, `ai_fill`, `fill_window_sec` |
| `match` | `rounds`, `fee_fragments` (null → default online fee) |
| `matches` | `required`, `credit` (`any_finish` \| `win` \| `flips_min`) |
| `eligibility` | mastery Value band, titles, slammer mode |
| `arcori` | `source` own/circulation/event_roster/intersect + filters |
| `arena` | `fixed_arena` \| `fixed_region` \| `seated_regions` |
| `media` | `banner`, `special_arena_background`, audio slots (`CatalogMediaMap`) |

## Runtime

1. Flutter picker → `GET /authuser/special_events/catalog` (progress + eligible)
2. Fee confirm → `pay_fee` with `eventId` + **`feeIntentId`** when fee &gt; 0 (`match_fee_ledger`; cancel/abort refunds same intent)
3. Dart `matchmaking/find` requires `eventId`; fetches `GET /service/special_events/match_rules?eventId=`
4. Lobby `targetSeats` / fill window / `roundsTotal` / arena / `eventId` on `select_arcori`
5. Finalize credits matches (`019` columns) + existing flip/design progress + achievements

## Progress

`player_special_event_progress`: flips, flipped_design_ids, matches_completed/won/credited, last_match_id. Quota met → `eligible: false`, `blockedReason: complete`.

## Docs note

Fee pay/refund is idempotent per `(user_id, feeIntentId, kind)` — Alembic `021`. Celebrate notify inserts are unique on `(user_id, msg_id)` when set — Alembic `022`.
Achievement-specific pipeline remains in [special-event-achievements.md](special-event-achievements.md). This file is the match-rules SSOT.
