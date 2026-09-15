# Achievements SSOT

**Status:** In Progress — catalog + finalize unlocks + notification celebrate  
**Created:** 2026-09-13  
**Last Updated:** 2026-09-14

Related: [core-match-loop.md](core-match-loop.md) · [daily-goals.md](daily-goals.md) · [unlock-types.md](unlock-types.md) · [mastery.md](mastery.md) · Dutch ACHIEVEMENTS_SYSTEM (reference) · [GDD](../Game_Specific/Arcori_Game_Design_Document_v0.4.md)

## Objective

Declarative achievements catalog (JSON SSOT, mtime hot-reload) with server-side unlock evaluation on match finalize and client `post_achieve_action` handlers — add rows of existing types without rebuilding backend or client.

## Screen model

**Achievements** is a **display of past unlocks only** (completed Daily Goals, Tasks, and match achievements). Active tracking lives on the **Tasks** screen. See [daily-goals.md](daily-goals.md).

## Semantics

- **Achievements ≠ GDD titles.** Master / Legacy Owner / Generation Creator stay on `avari_profiles.titles`. This catalog is match/progress unlocks (and later completed goals/tasks history).
- Unlock eval runs **after** gold/mastery writers in `POST /authuser/avari/match/finalize`. Practice skips.
- Finalize returns `achievementsUnlocked[]` (full rows + action) for summary chips; celebrate is **notification-driven**.
- After commit, finalize creates one durable instant per unlock (`achievements` / `progress` / `unlock_v1`).
- New JSON rows using existing `achievement_type` + `post_achieve_action.type` need only a file edit (hot-reload).

## SSOT

`app_codebase/python_base_05/bin/modules/achievements/data/achievements.json`

| Field | Role |
|-------|------|
| `id` | Stable persist key |
| `achievement_name` | Display title |
| `description` | Body |
| `achievement_type` | Evaluator key |
| `params` | Type params (`min`, `flag`, `design_id`, …) |
| `media` | Slot map `{ type, value }` plus nested `post_task` for post-completion anims/sfx |
| `post_achieve_action` | Client handler payload |

### v1 types

`total_wins`, `total_matches`, `total_flips`, `win_streak`, `match_flag`, `mastery_points`, `event_flips`, `event_arcori_cleared`

### v1 post actions (Flutter)

`none`, `move_to_screen` (screen slug via notification screen registry), `open_path`

## Persistence

- `player_achievements` — unique `(user_id, achievement_id)`
- `avari_profiles.win_streak_current` / `win_streak_best`

Migration: `016_player_achievements`

## HTTP

- `GET /authuser/achievements/catalog` — `{ revision, schemaVersion, achievements }`
- `GET /authuser/achievements/unlocked` — `{ ids, revision }`
- Profile also returns `achievementsUnlockedIds` + streak on `stats`

## Flutter

- Module `lib/modules/achievements/` — store, API, routes `/achievements`, drawer, unlock modal, post-action executor
- Screen lists **unlocked** rows only (past achievements)
- Unlock celebration: `media.animated_background` (or `post_task.animation`) via NotificationHost presenters (`unlock_v1`); CTA navigate View → achievements/tasks
- Post-match summary lists unlocks; does **not** open celebrate modals (Rematch stays free)
- Avari profile → View Achievements
- Active Daily Goals / Tasks → Tasks module (`/tasks`)
- Flip milestones: `first_flip` (`total_flips` min 1), `ten_flips` (`total_flips` min 10) — evaluated on finalize
- Special Event: `event_flips` / `event_arcori_cleared` — [special-event-achievements.md](special-event-achievements.md)

## Implementation Steps

- [x] JSON SSOT + mtime loader + type/action validation + revision
- [x] Migration + evaluators + finalize hook
- [x] Authuser catalog/unlocked routes + module_registry
- [x] Flutter catalog store, post-action executor, screen
- [x] Finalize → `create_for_user` unlock_v1 + NotificationHost safe-surface celebrate
- [ ] Apply Alembic `016` in target envs
- [ ] Optional: hydrate catalog on auth bootstrap (currently screen + unlock notify mark)

## Files Modified

- `app_codebase/python_base_05/bin/modules/achievements/**`
- `app_codebase/python_base_05/bin/models/player_progress.py` (`PlayerAchievement`)
- `app_codebase/python_base_05/bin/models/avari_profile.py` (streaks)
- `app_codebase/python_base_05/alembic/versions/016_player_achievements.py`
- `app_codebase/python_base_05/bin/modules/avari/avari_service.py`
- `app_codebase/python_base_05/bin/modules/module_registry.py`
- `app_codebase/flutter_base_06/lib/modules/achievements/**`
- `app_codebase/flutter_base_06/lib/modules/play/widgets/post_match_modal.dart`
- `Documentation/01_Active_Plans/achievements.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`

## Notes

Task Manager: App Dev checklist sync attempted; blocked by environment approval gate — re-sync when TM writes are allowed.

## Case study

Record: JSON SSOT + client action registry; finalize returns unlocks **and** creates `unlock_v1` instant notifications; celebrate on Home/Play-idle only (achievements ≠ titles).
