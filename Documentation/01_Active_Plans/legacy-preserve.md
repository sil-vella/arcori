# Legacy preserve (in-app + website checkout)

**Status:** In Progress  
**Created:** 2026-09-15  
**Last Updated:** 2026-09-18

Related: [core-match-loop.md](core-match-loop.md) · [arcori-standings-surface.md](arcori-standings-surface.md) · [website checkout contract](../00_System_Wide/arcori-website-legacy-checkout.md) · [DEEP_LINKS.md](../03_Base/Flutter/DEEP_LINKS.md)

## Objective

Wire Legacy preserve: first-to-reach / 7d offer / 30d leader window / auto-close Lost, with **external website checkout** for the physical mint and app deep-link return to celebrate the already-fulfilled digital mint.

## Product rules

| Rule | Behavior |
|------|----------|
| First reach | First player whose mastery crosses `preservationRequirement` gets **7-day** Preserve/Decline offer (idempotent claim). |
| Decline / expire | → **Leader window**; each new leader resets **+30d**; preserve only after **30d uninterrupted** lead. |
| Auto-close | Mastery ≥ `closureMilestone` before preserve → **Legacy Lost**, echo gen N+1 (new serial + **random approved disc color**), no Gen Creator / Legacy Owner. |
| Preserve success | Website fulfill → Trove + Legacy Owner + Generation Creator + Museum + echo N+1 (same color rule). |
| Echo delta | Between gens, **only `color`** changes (from `ALLOWED_ARCORI_COLORS` / Flutter `kArcoriAccentHexes`); art and Lottie reuse `art_basename`. |
| Echo mastery | Soft reset: closed mastery kept; echo seeded at **30%** (min 1, cap preserve−1); profile **Closed Generations** shows mastery-at-close **and** `echoMasterySeeded` into the next gen. |
| Offer UX | **NotificationHost** progress celebrate (`legacy` / `offer_v1`) — not post-match modal. |
| Multi-design | One notification lists all offers from the same match; one checkout URL / fulfill mints all. |
| Leader proximity | During **`leader_window` only**, when a challenger closes the gap: **one instant per gap 5→1** for both leader (`pressure_v1`) and challenger (`chase_v1`). CTA **Play now** → `play`. `msg_id` includes gap so each position notifies once. |

## Payment

In-app never collects cards. `preserve/start` (batch `offers[]`) → system browser with `designIds` → website charges → `POST /service/legacy/fulfill` (mints all intent items) → deep link `arcori://legacy-preserve-complete` → `preserve/complete` reads ledger only.

## Implementation Steps

- [x] Alembic: lifecycle, preserve intent, fulfill ledger, museum row (`023_legacy_preserve`)
- [x] Alembic: intent `items_json` for batch checkout (`024_legacy_intent_items`)
- [x] Legacy module (errors, repo, service, routes) + registry
- [x] Finalize mastery hook + cron expire first-offer
- [x] Fulfill writer (idempotent `orderId`, batch mint) + complete soft-processing
- [x] Instant notify `offer_v1` (one msg per match, all designs) after finalize
- [x] Flutter NotificationHost celebrate (Preserve all / Decline) + batch checkout
- [x] Remove post-match legacy offer wiring
- [x] Website contract doc (batch query + fulfill body)
- [x] Idempotency tests + DEEP_LINKS + App Dev TM
- [x] Leader-window proximity: `pressure_v1` / `chase_v1` per gap 5..1 + Play now
- [x] Museum browse (closed Preserved/Lost + write history) — [museum-browse.md](museum-browse.md)
- [x] Echo disc **color** from approved palette (`pick_echo_color`)
- [x] Echo mastery soft seed (30%) + access copy on new serial
- [x] Profile **Closed Generations** (`player_closed_generations` Alembic `027`/`028`; caption includes seeded amount)

## Current progress

Preserve/Lost/fulfill/Museum/proximity live. Echo now changes color only in catalog, seeds mastery for everyone with closed-gen points, and surfaces closed history on Avari. Remaining: active-window play select (separate plan).

## Files Modified

- `app_codebase/python_base_05/bin/modules/legacy/**`
- `app_codebase/python_base_05/bin/models/legacy_preserve.py`
- `app_codebase/python_base_05/bin/models/player_progress.py` (`PlayerClosedGeneration`)
- `app_codebase/python_base_05/alembic/versions/023_legacy_preserve.py`
- `app_codebase/python_base_05/alembic/versions/024_legacy_intent_items.py`
- `app_codebase/python_base_05/alembic/versions/027_player_closed_generations.py`
- `app_codebase/python_base_05/alembic/versions/028_closed_gen_echo_seed.py`
- `app_codebase/python_base_05/bin/modules/avari/avari_service.py` (finalize + notify + profile closed gens)
- `app_codebase/python_base_05/bin/modules/avari/mastery_economy.py` (`echo_mastery_seed`)
- `app_codebase/python_base_05/bin/modules/module_registry.py`
- `app_codebase/python_base_05/test/test_legacy_preserve.py`
- `app_codebase/flutter_base_06/lib/modules/legacy/**`
- `app_codebase/flutter_base_06/lib/modules/avari/**` (Closed Generations section)
- `app_codebase/flutter_base_06/lib/modules/notifications/**`
- `Documentation/01_Active_Plans/legacy-preserve.md`

## Notes

- Digital mint never unlocked from an unsigned deep link alone.
- Museum browse UI shipped — [museum-browse.md](museum-browse.md). My Mastery standings ranks remain follow-on.
- Apply migrations through `028_closed_gen_echo_seed` on API envs (local applied).
- Proximity jumps that skip gaps (e.g. 7→3) emit one message per crossed position (5, 4, and 3).
- **Follow-on:** players cannot target an active-window design in match pick today (weighted/random only) — track in [active-window-arcori-play-selection.md](active-window-arcori-play-selection.md).
- **Debug:** fixture-driven finalize from Home (not a forced Quick Join) — see active-window plan Notes.
- Closed Generations caption: `Gen N · X at close → +Y seeded to Gen N+1 · Lost|Preserved`.
- Task Manager: App Dev checklist synced for echo seed + Closed Generations.