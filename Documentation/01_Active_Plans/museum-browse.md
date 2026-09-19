# Museum browse (closed Legacy history)

**Status:** Completed  
**Created:** 2026-09-17  
**Last Updated:** 2026-09-17

Related: [legacy-preserve.md](legacy-preserve.md) · [03_CASE_STUDY.md](03_CASE_STUDY.md) · GDD Museum ≠ Trove ≠ Chronicle

## Objective

Ship a world **Museum** screen backed by existing `museum_generations` (no new table): list/filter closed Preserved vs Lost generations with a factual write-history detail per piece. Rename the profile section that showed personal Trove from “Museum” → **Trove**.

## Product rules

| Surface | Shows |
|---------|--------|
| **Museum** (`/museum`) | All `museum_generations` rows (world), Preserved + Lost |
| **Trove** | Viewer’s `player_trove` only (profile section renamed) |
| **Write history (v1)** | Factual lifecycle caption in `meta_json.historySummary` — not Chronicle lore |

## Implementation Steps

- [x] Alembic indexes on `museum_generations` (`legacy_state`, `closed_at`) — `025_museum_generations_indexes`
- [x] Enrich `meta_json` at preserve/lost write (`historySummary`, `actorDisplayName`, `actorRole`, …)
- [x] Repo `list_museum_generations` / `get_museum_generation`
- [x] Service `list_museum` / `get_museum_item` + catalog + display-name enrich
- [x] `GET /authuser/museum` + `GET /authuser/museum/item` + `legacy/museum_not_found`
- [x] Flutter `museum` module: screen, detail modal, routes, drawer
- [x] Profile section rename Museum → Trove
- [x] Docs + App Dev TM checklist

## Files Modified

- `app_codebase/python_base_05/alembic/versions/025_museum_generations_indexes.py`
- `app_codebase/python_base_05/bin/models/legacy_preserve.py`
- `app_codebase/python_base_05/bin/modules/legacy/legacy_repository.py`
- `app_codebase/python_base_05/bin/modules/legacy/legacy_service.py`
- `app_codebase/python_base_05/bin/modules/legacy/legacy_app.py`
- `app_codebase/python_base_05/bin/modules/legacy/legacy_errors.py`
- `app_codebase/python_base_05/bin/core/notifications/screen_names.py`
- `app_codebase/flutter_base_06/lib/modules/museum/**`
- `app_codebase/flutter_base_06/lib/modules/module_registry.dart`
- `app_codebase/flutter_base_06/lib/core/navigation/app_paths.dart`
- `app_codebase/flutter_base_06/lib/modules/avari/screens/avari_profile_screen.dart`
- `Documentation/01_Active_Plans/museum-browse.md`
- `Documentation/01_Active_Plans/legacy-preserve.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/01_Active_Plans/03_CASE_STUDY.md`

## Notes

- Apply migration `025_museum_generations_indexes` on API containers before relying on list filters at scale.
- Pre-existing museum rows without `historySummary` are filled at read time.
- Out of scope: Chronicle authoring, standings snapshot at close, My Mastery tab, active-window play selection.
