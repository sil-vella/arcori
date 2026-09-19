# Daily Goals (server-driven)

**Status:** In Progress  
**Created:** 2026-09-14  
**Last Updated:** 2026-09-19

Related: [core-match-loop.md](core-match-loop.md) · [achievements.md](achievements.md) · [unlock-types.md](unlock-types.md) · [returning-player-startup-flow.md](returning-player-startup-flow.md) · [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

## Objective

Server-driven Daily Goals (featured missions + **Daily Cache** claim gate): JSON catalog SSOT, per-goal **value** with miss-reset and Gold Arcori **continue**, generic Flutter UI so new goals of existing `task_type`s need no client rebuild.

## Semantics

- Each goal has `id`, `task_type` + `params`, `value` rules, `continue` fee, opaque `reward`, `post_complete_action`.
- `cadence: daily` uses UTC day keys. Miss → `miss_pending` (value held) → Continue (spend Gold Arcori) or Accept reset (`value=0`).
- Practice matches do not advance goals.
- **Daily Cache** (`id` remains `daily_mystery_box`, `task_type: claim_gate`): after required featured goals complete today, `POST /claim` grants **+2 Gold Fragments** (`reward.kind: gold_fragments`, JSON-tunable `amount`). Alias `mystery_box` still accepted. Sets `avari.daily_cache_claimed_at` and emits `complete_v1` for celebrate. Double-claim / gate-not-met rejected.
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
| `POST /authuser/daily_goals/claim` | `claim_gate` → grant fragments + `reward.status: granted` |

Finalize returns `daily` (progress payload) after gold/mastery/achievements via `apply_match_event`.

## Persistence

`player_daily_goal_progress` — unique `(user_id, goal_id)`; fields: `value`, `day_key`, `progress_today`, `completed_today`, `miss_pending`, `last_completed_day_key`.

`avari_profiles.daily_cache_claimed_at` — stamp on successful Cache claim (UI prefers progress `completed_today`).

Migration: `017_player_daily_goal_progress`

## Screen model

| Screen | Role |
|--------|------|
| **Tasks** (`/tasks`) | Active work: **Daily Goals** + **Tasks**; detail Claim / Continue / Reset |
| **Achievements** (`/achievements`) | **Past unlocks only** — completed goals/tasks plus match achievements (not the live tracker) |

## Flutter

Module `lib/modules/tasks/` — catalog/progress stores, Tasks list (Cache ready/claimed/locked), detail Claim CTA, `TasksApiClient.claimGoal` / `continueGoal` / `acceptReset`. Post-match Daily block: featured lines + Cache status + **View Daily** → `/tasks` (Done path; not Rematch). Soft once-per-day returning nudge (`DailyMissionsNudgeHost`) after auth → Open `/tasks` or Later (prefs day key). Notification slugs `tasks` / `daily_goals` → Tasks. Newly completed goals become durable **instant** notifications (`source=daily_goals`, `subtype=complete_v1`); NotificationHost celebrates on Home / Play-idle only (never blocks Rematch). Client never evaluates task progress.

## Implementation Steps

- [x] Plan + case study / master links
- [x] JSON SSOT + mtime loader (`gold_fragments` amount + mystery_box alias)
- [x] Migration + repository + rollover/continue
- [x] Evaluators + finalize + routes
- [x] Flutter Tasks UI + post-match summary
- [x] Finalize → complete_v1 notifications + safe-surface celebrate
- [x] Daily Cache claim loot (+2 fragments) + Tasks claim UI
- [x] Post-match Daily polish + View Daily CTA
- [x] Soft returning Daily Missions nudge (once per UTC day)

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
- `app_codebase/python_base_05/tests/modules/daily_goals/test_claim_goal.py`
- `app_codebase/flutter_base_06/lib/modules/tasks/**`
- `app_codebase/flutter_base_06/lib/modules/module_registry.dart`
- `app_codebase/flutter_base_06/lib/modules/play/widgets/post_match_modal.dart`
- `app_codebase/flutter_base_06/lib/app_init.dart`
- `app_codebase/flutter_base_06/test/modules/tasks/tasks_models_test.dart`

## Notes

Day boundary UTC v1. No-miss streak = consecutive days all **featured** goals completed; mirrored on `avari_profiles.daily_no_miss_streak`.

Full startup queue (News, overnight, etc.) stays in [returning-player-startup-flow.md](returning-player-startup-flow.md) — this slice only soft-nudges to Tasks.
