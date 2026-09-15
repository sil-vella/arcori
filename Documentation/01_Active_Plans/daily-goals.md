# Daily Goals (server-driven)

**Status:** In Progress  
**Created:** 2026-09-14  
**Last Updated:** 2026-09-14

Related: [core-match-loop.md](core-match-loop.md) · [achievements.md](achievements.md) · [unlock-types.md](unlock-types.md) · [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

## Objective

Server-driven Daily Goals (featured missions + mystery-box / Daily Cache slot): JSON catalog SSOT, per-goal **value** with miss-reset and Gold Arcori **continue**, generic Flutter UI so new goals of existing `task_type`s need no client rebuild.

## Semantics

- Each goal has `id`, `task_type` + `params`, `value` rules, `continue` fee, opaque `reward`, `post_complete_action`.
- `cadence: daily` uses UTC day keys. Miss → `miss_pending` (value held) → Continue (spend Gold Arcori) or Accept reset (`value=0`).
- Practice matches do not advance goals.
- Rewards / mystery loot tables are **deferred** (claim returns stub).
- New JSON rows with existing evaluators: hot-reload only. New `task_type`: backend deploy. Unknown client actions: soft no-op.

## Media (shared catalog pattern)

Every goal / achievement / task row may include:

```json
"media": {
  "background": { "type": "image", "value": "/catalog-media/.../background.webp" },
  "button": { "type": "image", "value": "/catalog-media/.../button.webp" },
  "icon": { "type": "lottie", "value": "/catalog-media/.../icon.json" },
  "post_task": {
    "animation": { "type": "lottie", "value": "/catalog-media/.../post_task/animation.json" },
    "burst": { "type": "image", "value": "/catalog-media/.../post_task/burst.webp" },
    "sfx": { "type": "audio", "value": "/catalog-media/.../post_task/cheer.mp3" }
  }
}
```

- Flat slot keys are free-form (`background`, `button`, `icon`, …).
- Each leaf: **`type`** + **`value`** (public path or URL).
- **`post_task`**: nested map of multiple post-completion visuals (animation, sfx, …). Aliases `post_achieve` / `post_goal` normalize to `post_task`. List form `{ key, type, value }[]` also accepted.
- Client resolves root-relative `value` against the API host; unknown slots/types soft-ignore (no Flutter rebuild to add art).
- Helper: `core.utils.media_fields.normalize_media_map` / Flutter `CatalogMediaMap`.

## SSOT

`app_codebase/python_base_05/bin/modules/daily_goals/data/daily_goals.json`

### v1 `task_type`s

`matches_completed`, `flips_completed`, `login`, `claim_gate`

~~`wins_completed`~~ removed — matches are flip/mastery framed, not win/loss.

### HTTP

| Route | Role |
|-------|------|
| `GET /authuser/daily_goals/catalog` | Catalog + revision |
| `GET /authuser/daily_goals/progress` | Rollover + progress rows + `noMissStreak` |
| `POST /authuser/daily_goals/continue` | `{ goalId }` preserve value |
| `POST /authuser/daily_goals/accept_reset` | `{ goalId }` value→0 |
| `POST /authuser/daily_goals/claim` | `claim_gate` / mystery box stub |

Finalize returns `daily` (progress payload) after gold/mastery/achievements via `apply_match_event`.

## Persistence

`player_daily_goal_progress` — unique `(user_id, goal_id)`; fields: `value`, `day_key`, `progress_today`, `completed_today`, `miss_pending`, `last_completed_day_key`.

Migration: `017_player_daily_goal_progress`

## Screen model

| Screen | Role |
|--------|------|
| **Tasks** (`/tasks`) | Active work: **Daily Goals** + **Tasks** (catalog `section`: `daily_goals` \| `tasks`) with live progress |
| **Achievements** (`/achievements`) | **Past unlocks only** — completed goals/tasks plus match achievements (not the live tracker) |

## Flutter

Module `lib/modules/tasks/` — catalog/progress stores, Tasks screen (two groups), stub detail, drawer, routes `/tasks` + `/tasks/detail`. Notification slugs `tasks` / `daily_goals` → Tasks. Post-match Daily section binds finalize `daily` (summary only). Newly completed goals (`daily.goalsCompleted`) become durable **instant** notifications (`source=daily_goals`, `subtype=complete_v1`) created in finalize; NotificationHost celebrates on Home / Play-idle only (never blocks Rematch). Client never evaluates tasks.

## Implementation Steps

- [x] Plan + case study / master links
- [ ] JSON SSOT + mtime loader
- [x] Migration + repository + rollover/continue
- [x] Evaluators + finalize + routes
- [x] Flutter Tasks UI + post-match summary
- [x] Finalize → complete_v1 notifications + safe-surface celebrate

## Files Modified

- `Documentation/01_Active_Plans/daily-goals.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/01_Active_Plans/03_CASE_STUDY.md`
- `Documentation/01_Active_Plans/core-match-loop.md`
- `app_codebase/python_base_05/bin/modules/daily_goals/**`
- `app_codebase/python_base_05/bin/models/player_progress.py`
- `app_codebase/python_base_05/alembic/versions/017_player_daily_goal_progress.py`
- `app_codebase/python_base_05/bin/modules/module_registry.py`
- `app_codebase/python_base_05/bin/modules/avari/avari_service.py`
- `app_codebase/flutter_base_06/lib/modules/tasks/**`
- `app_codebase/flutter_base_06/lib/modules/module_registry.dart`
- `app_codebase/flutter_base_06/lib/modules/play/widgets/post_match_modal.dart`

## Notes

Day boundary UTC v1. No-miss streak = consecutive days all **featured** goals completed; mirrored on `avari_profiles.daily_no_miss_streak`.

Task Manager: skipped this turn — credentialed TM sync was blocked by auto-review; markdown plan/docs updated locally.
