# Legacy preserve (in-app + website checkout)

**Status:** In Progress  
**Created:** 2026-09-15  
**Last Updated:** 2026-09-15

Related: [core-match-loop.md](core-match-loop.md) · [arcori-standings-surface.md](arcori-standings-surface.md) · [website checkout contract](../00_System_Wide/arcori-website-legacy-checkout.md) · [DEEP_LINKS.md](../03_Base/Flutter/DEEP_LINKS.md)

## Objective

Wire Legacy preserve: first-to-reach / 7d offer / 30d leader window / auto-close Lost, with **external website checkout** for the physical mint and app deep-link return to celebrate the already-fulfilled digital mint.

## Product rules

| Rule | Behavior |
|------|----------|
| First reach | First player whose mastery crosses `preservationRequirement` gets **7-day** Preserve/Decline offer (idempotent claim). |
| Decline / expire | → **Leader window**; each new leader resets **+30d**; preserve only after **30d uninterrupted** lead. |
| Auto-close | Mastery ≥ `closureMilestone` before preserve → **Legacy Lost**, echo gen N+1, no Gen Creator / Legacy Owner. |
| Preserve success | Website fulfill → Trove + Legacy Owner + Generation Creator + Museum + echo N+1. |
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

## Files Modified

- `app_codebase/python_base_05/bin/modules/legacy/**`
- `app_codebase/python_base_05/bin/models/legacy_preserve.py`
- `app_codebase/python_base_05/alembic/versions/023_legacy_preserve.py`
- `app_codebase/python_base_05/alembic/versions/024_legacy_intent_items.py`
- `app_codebase/python_base_05/bin/modules/avari/avari_service.py` (finalize + notify)
- `app_codebase/python_base_05/bin/modules/module_registry.py`
- `app_codebase/python_base_05/test/test_legacy_preserve.py`
- `app_codebase/flutter_base_06/lib/modules/legacy/**`
- `app_codebase/flutter_base_06/lib/modules/notifications/**`
- `app_codebase/flutter_base_06/lib/core/navigation/app_paths.dart` / `app_router.dart`
- `app_codebase/flutter_base_06/lib/modules/play/widgets/post_match_modal.dart`
- `app_codebase/flutter_base_06/android/app/src/main/AndroidManifest.xml`
- `Documentation/00_System_Wide/arcori-website-legacy-checkout.md`
- `Documentation/03_Base/Flutter/DEEP_LINKS.md`
- `Documentation/01_Active_Plans/legacy-preserve.md`

## Notes

- Digital mint never unlocked from an unsigned deep link alone.
- Full Museum browse UI and My Mastery standings ranks remain follow-on.
- Apply migration `024_legacy_intent_items` on API containers before batch checkout in env.
- Proximity jumps that skip gaps (e.g. 7→3) emit one message per crossed position (5, 4, and 3).
- **Follow-on:** players cannot target an active-window design in match pick today (weighted/random only) — track in [active-window-arcori-play-selection.md](active-window-arcori-play-selection.md).
