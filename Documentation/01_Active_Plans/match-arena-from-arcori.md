# Match arena from seated Arcori

**Status**: Completed  
**Created**: 2026-09-06  
**Last Updated**: 2026-09-13

Related: [match-hot-state.md](match-hot-state.md) · [catalog-hot-reload.md](catalog-hot-reload.md) · [stub-match-arcori-selection.md](stub-match-arcori-selection.md)

## Objective

After seated Arcori are known on **Quick Start** and **Invite**, pick a Velora arena from `01_regions.json` and paint that image as the match background. In the same pick, stamp a non-player **Gatherer** Arcori from that region.

**Not this pass:** Special Event (separate arena rules later). Practice stays on the stub `arenaId` (no catalog pick, no Gatherer). UI display of the Gatherer can follow later; snapshot + catalog freeze are required.

## Rule

Count `location.regionCode` on the seated designs:

1. **Majority** — any region with **2 or more** seats → random arena in that region.
2. **All different** (or no majority) → random region among catalog regions that have arenas, then a random arena in it.
3. Unknown / missing region codes are ignored. If none resolve, same as (2). If the catalog has no arenas, the client keeps the stub `arenaId` and no image.

**Gatherer** (same `select_arena` response, after region is known):

1. Pool = circulating static catalog designs with `location.regionCode == chosen_region` (any series).
2. Exclude SLM / KIN / `type=slammer` and all seated player `arcoriIds`.
3. Weighted pick by each design’s `selectionWeight` (0.01–10.00; region standing is constant within one region).
4. Fail closed: omit `gathererArcoriId` if the pool is empty.

**Seat uniqueness** (upstream `select_arcori` / `select_for_seats`): no duplicate Arcori ids across seats; Gatherer also excludes those ids.

## Architecture

| Layer | Owns |
|-------|------|
| FastAPI catalog | `select_arena_for_arcori_ids` — region counts + RNG arena + Gatherer; `select_for_seats` unique ids |
| Dart match room | After `select_arcori`, **only** if `matchType.code` is `quickStart` or `invite`: `POST /service/catalog/select_arena`; stamp `arenaId` + `arenaImageUrl` + optional `gathererArcoriId`; freeze Gatherer with seat discs |
| Flutter | Paints `arenaImageUrl` when the snapshot has it; parses/carries `gathererArcoriId` (display deferred). No practice HTTP pick. |
| `/catalog-media` | discs from `assets/images/arcori`; arenas from sibling `assets/images/velora/arenas/…` served at `/catalog-media/velora/arenas/…` |

Do **not** parse `01_regions.json` in Dart or Flutter. Special Event keeps the stub arena until its own rules exist. Gatherer is **not** a `MatchSeat`.

## Implementation Steps

- [x] Active plan + App Dev checklist
- [x] Python `select_arena` + service/authuser routes + tests
- [x] Dart `startFromLobby` gated to quickStart/invite + snapshot `arenaImageUrl`
- [x] Flutter match background from snapshot
- [x] Docker velora mount + docs + TM
- [x] Unique seat Arcori ids in `select_for_seats`
- [x] Gatherer pick + `gathererArcoriId` on snapshot / freeze / Flutter parse

## Current Progress

Shipped: FastAPI arena + Gatherer, unique seat picks, Dart Quick Start / Invite stamp + freeze, Flutter carries `gathererArcoriId`, nested velora media mount.

## Next Steps

Special Event arena rules (separate). Optional Gatherer UI on the match surface.

## Files Modified

- `app_codebase/python_base_05/bin/modules/catalog/catalog_select.py`
- `app_codebase/python_base_05/bin/modules/catalog/catalog_app.py`
- `app_codebase/python_base_05/tests/modules/catalog/test_catalog_select.py`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_models.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_catalog_client.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_service.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_store.dart`
- `app_codebase/dart_bkend_base_02/test/match_service_test.dart`
- `app_codebase/dart_bkend_base_02/test/matchmaking_service_test.dart`
- `app_codebase/flutter_base_06/lib/modules/match/state/match_snapshot_state.dart`
- `app_codebase/flutter_base_06/lib/modules/match/widgets/practice_match_surface.dart`
- `app_codebase/flutter_base_06/lib/core/modal/app_fullscreen_modal.dart`
- `docker/docker-compose.yml`
- `docker/docker-compose.debug.yml`

## Notes

- Fail closed: catalog/network errors keep stub `arena_velora_plaza` and no background image; empty Gatherer pool omits the field.
- Invite (2 seats): 2 same → that region; 2 different → random region + arena (rule 2).
- Authuser `select_arena` is available for later clients; Flutter practice does not call it.
- Rematch re-runs arena + Gatherer with new seated picks (same as arena today).
- Product name is **Gatherer** (not “host” — lore already avoids host for lobby authority / Caller).

## Case study

Arena + Gatherer live in FastAPI catalog; match snapshot carries `arenaId` + `arenaImageUrl` + optional `gathererArcoriId`. Seat Arcori ids are unique across the table and vs Gatherer.

## Task Manager

App Dev (`32`) checklist `275` (done) + note `276`.
