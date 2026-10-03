# Series Circulation Switch

**Status:** Completed  
**Created:** 2026-09-30  
**Last Updated:** 2026-09-30

## Objective

Add a hot-reloaded catalog JSON master switch per series. A design circulates only when **both** its series is `active: true` and its own `worldState` is `Active`. Launch: Genesis (`001`) and Pioneers (`002`) on; all other series off. Player access rows stay when a series is off and become playable again when turned on.

## Done

- [x] `data/03_series.json` — series list + `active` flags (runtime, mtime-cached)
- [x] `catalog_loader` meta name `series`
- [x] `list_series_catalog` / `series_is_active` / `resolve_design_series_key` in `current_series.py` (replaces hardcoded `SERIES_CATALOG`)
- [x] Dual gate in match select, Velora series + circulating index, starter pool, profile `circulating`
- [x] Series-off does **not** revoke `player_design_access` (Closed generations still revoke)
- [x] Kin resolves as Kin series (not legacy Genesis stamp); Kin off until switched on
- [x] Unit tests `test_series_switch.py`

## Launch state

| Series | active |
|--------|--------|
| Creation | false |
| Genesis | true |
| Pioneers | true |
| Foundations | false |
| Civilizations | false |
| Kin | false |

## Files

- `app_codebase/python_base_05/bin/modules/catalog/data/03_series.json`
- `catalog_loader.py`, `current_series.py`, `catalog_select.py`, `catalog_service.py`
- `starter_grant.py`, `avari_service.py`
- `tests/modules/catalog/test_series_switch.py`

## Notes

- Flip a series by editing `03_series.json` `active` (no process restart in debug compose).
- `CURRENT_SERIES` (mint stamp) remains Genesis — separate from the Velora/browse switch.
- Task Manager: App Dev checklist items 355/356 marked done (Series circulation switch).
