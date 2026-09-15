# Shared unlock_type (goals, tasks, achievements)

**Status:** Spec / Plan  
**Created:** 2026-09-14  
**Last Updated:** 2026-09-14

Related: [daily-goals.md](daily-goals.md) · [achievements.md](achievements.md) · [core-match-loop.md](core-match-loop.md) · [03_CASE_STUDY.md](03_CASE_STUDY.md)

## Objective

One shared **`unlock_type`** vocabulary (plus `params`) across Daily Goals, Tasks, Achievements (and later caches / missions) so **game events** can decide what to advance or unlock without each module inventing its own type field.

## Problem today

| Catalog | Condition field | When evaluated |
|---------|-----------------|----------------|
| Achievements | `achievement_type` | Match finalize only (`apply_match_unlocks`) |
| Daily Goals / Tasks | `task_type` | Match finalize path (partial) + login / claim |

Parallel names, separate registries, hard to add `special_event_match_end` or `leaderboard_position` without duplicating logic.

## Proposal — two layers

### 1. Event (when we run)

Closed set of **emit points**. Each builds a typed **context** and asks the unlock core to process relevant catalog rows.

| Event id | Emitted from (v1+) | Context highlights |
|----------|--------------------|--------------------|
| `match_end` | Online finalize (non-practice) | flips, won, matchType, mastery_after, totals, streaks |
| `special_event_match_end` | Finalize when `matchType` is specialEvent | same + `eventId` / subtype |
| `invite_match_end` | Finalize when invite | same + invite flags |
| `login` | Auth / session bootstrap | dayKey |
| `claim` | Explicit claim route | goalId |
| `leaderboard_position` | Standings writer (later) | designId, rankBefore, rankAfter, region |
| `mastery_threshold` | After mastery writers (or folded into match_end) | designId, points |

Practice emits **nothing** (no progression).

### 2. unlock_type (what condition)

Closed set shared by all catalogs. Evaluators: `(params, ctx) → bool` (achievement-style) or `(params, ctx) → progress_delta` (daily/task counters).

| unlock_type | Kind | Params (v1) | Typical events |
|-------------|------|-------------|----------------|
| `matches_completed` | counter / threshold | `min` | `match_end`, `special_event_match_end`, … |
| `flips_completed` | counter / threshold | `min` | match_*_end |
| `wins_completed` | counter / threshold | `min` | match_*_end |
| `total_wins` | lifetime threshold | `min` | match_*_end |
| `total_matches` | lifetime threshold | `min` | match_*_end |
| `total_flips` | lifetime threshold | `min` | match_*_end |
| `win_streak` | lifetime threshold | `min` | match_*_end |
| `mastery_points` | design threshold | `design_id?`, `min` | match_*_end |
| `match_flag` | flag present | `flag` | match_*_end |
| `login` | once per day | — | `login` |
| `claim_gate` | manual claim | — | `claim` |
| `leaderboard_rank` | rank crossed | `max_rank`, `design_id?` | `leaderboard_position` |
| `match_type` | played mode | `codes: []` | match_*_end |

**Kind** matters for persistence:

- **threshold / boolean** → Achievements (unlock once, persist id)
- **counter** → Daily Goals / Tasks (`progress_today` toward `min`, cadence reset)
- Same `unlock_type` can serve both if the catalog row declares **mode** via existing `section` / permanence (achievement vs daily), not a second type field.

### Optional filter: `unlock_events`

Default: derive from unlock_type (e.g. `login` only on `login`).  
Override when needed:

```json
"unlock_events": ["special_event_match_end"]
```

So a daily can require special-event matches only without a new unlock_type.

## Catalog row shape (target)

```json
{
  "id": "land_three_flips",
  "name": "Land three flips",
  "section": "daily_goals",
  "cadence": "daily",
  "unlock_type": "flips_completed",
  "params": { "min": 3 },
  "unlock_events": ["match_end", "special_event_match_end", "invite_match_end"],
  "media": { },
  "post_complete_action": { "type": "none" }
}
```

Achievements:

```json
{
  "id": "first_victory",
  "achievement_name": "First victory",
  "unlock_type": "total_wins",
  "params": { "min": 1 },
  "post_achieve_action": { "type": "move_to_screen", "screen": "avari" }
}
```

### Migration aliases

Loaders accept legacy keys and normalize:

- `achievement_type` / `task_type` → `unlock_type`
- Missing `unlock_events` → defaults from unlock_type map

## Architecture

```text
Event emitter (finalize / login / standings / …)
  → UnlockEventContext { event, user_id, payload }
  → core unlock dispatcher
       for each catalog sink (achievements, daily_goals, …):
         filter rows by unlock_events ∩ event
         run unlock_type evaluator
         sink.apply (persist unlock OR add progress)
  → aggregate client payload (achievementsUnlocked[], dailyGoals, …)
```

**New shared module (proposed):** `python_base_05/bin/core/unlock/` or `modules/unlock/`

| File | Role |
|------|------|
| `unlock_types.py` | Closed `UNLOCK_TYPES` + default event map |
| `unlock_events.py` | Closed event ids + context builders |
| `unlock_evaluators.py` | Registry `unlock_type → fn` |
| `unlock_dispatch.py` | `dispatch_unlock_event(session, event, ctx)` |

Catalog modules keep **persistence + rewards + media**; they register as **sinks**, not private type enums.

Flutter: one `unlockType` on catalog models; event list optional for client display only (server remains SSOT for eval).

## What stays separate

| Concern | Owner |
|---------|--------|
| Section / cadence / miss-continue / value streak | Daily Goals module |
| Once-forever unlock table | Achievements module |
| post_task media + post_*_action | Per catalog (shared media helper already) |
| Fee / gold / mastery writers | Avari finalize (emit event **after** writers) |

## Implementation steps

1. [ ] Spec lock: event list + unlock_type list + default event map (this doc)
2. [ ] Add `core/unlock` (or `modules/unlock`) types + evaluators (port existing)
3. [ ] Achievements loader: `unlock_type` (+ alias); wire finalize → `dispatch(match_end)`
4. [ ] Daily goals loader: `unlock_type` (+ alias); `apply_match_event` → dispatch
5. [ ] Emit `special_event_match_end` / `invite_match_end` from finalize by matchType
6. [ ] Flutter models: prefer `unlockType`, keep legacy parse
7. [ ] Later: `leaderboard_position` emitter + `leaderboard_rank` type
8. [ ] Case study + master plan row

## Non-goals (this slice)

- Client-side unlock evaluation
- Rewarding / mystery tables
- Renaming Achievements screen semantics (still past unlocks display)

## Open questions

1. **Name:** keep dual `achievement_type` forever as alias, or migrate JSON fully to `unlock_type` in one pass?
2. **Counters vs thresholds:** one `flips_completed` with sink-defined semantics, or split `session_flips` vs `lifetime_flips`?
3. **Fee work in flight:** pre-match fee is separate; unlock dispatch still hooks **after** finalize writers.

## Case study

Pending lock — record under Technical once event + unlock_type sets are agreed.

## Task Manager

App Dev checklist: “Shared unlock_type + event dispatch (goals/tasks/achievements)” — sync when implementation starts.
