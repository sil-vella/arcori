# Match arena from seated Arcori

**Status**: Completed  
**Created**: 2026-09-06  
**Last Updated**: 2026-09-06

Related: [match-hot-state.md](match-hot-state.md) · [catalog-hot-reload.md](catalog-hot-reload.md) · [stub-match-arcori-selection.md](stub-match-arcori-selection.md)

## Objective

After seated Arcori are known on **Quick Start** and **Invite**, pick a Velora arena from `01_regions.json` and paint that image as the match background.

**Not this pass:** Special Event (separate arena rules later). Practice stays on the stub `arenaId` (no catalog pick).

## Rule

Count `location.regionCode` on the seated designs:

1. **Majority** — any region with **2 or more** seats → random arena in that region.
2. **All different** (or no majority) → random region among catalog regions that have arenas, then a random arena in it.
3. Unknown / missing region codes are ignored. If none resolve, same as (2). If the catalog has no arenas, the client keeps the stub `arenaId` and no image.

## Architecture

| Layer | Owns |
|-------|------|
| FastAPI catalog | `select_arena_for_arcori_ids` — region counts + RNG arena |
| Dart match room | After `select_arcori`, **only** if `matchType.code` is `quickStart` or `invite`: `POST /service/catalog/select_arena`; stamp `arenaId` + `arenaImageUrl` |
| Flutter | Paints `arenaImageUrl` when the snapshot has it (online Quick Start / Invite). No practice HTTP pick. |
| `/catalog-media` | discs from `assets/images/arcori`; arenas from sibling `assets/images/velora` served at `/catalog-media/velora/…` |

Do **not** parse `01_regions.json` in Dart or Flutter. Special Event keeps the stub arena until its own rules exist.

## Implementation Steps

- [x] Active plan + App Dev checklist
- [x] Python `select_arena` + service/authuser routes + tests
- [x] Dart `startFromLobby` gated to quickStart/invite + snapshot `arenaImageUrl`
- [x] Flutter match background from snapshot
- [x] Docker velora mount + docs + TM

## Current Progress

Shipped: FastAPI pick, Dart Quick Start / Invite stamp, Flutter paints `arenaImageUrl`, nested velora media mount.

## Next Steps

Special Event arena rules (separate). Recreate `Arcori_api` so the sibling Velora bind is live.

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

- Fail closed: catalog/network errors keep stub `arena_velora_plaza` and no background image.
- Invite (2 seats): 2 same → that region; 2 different → random region + arena (rule 2).
- Authuser `select_arena` is available for later clients; Flutter practice does not call it.

## Case study

Arena pick lives in FastAPI catalog; match snapshot carries `arenaId` + `arenaImageUrl`.

## Task Manager

App Dev (`32`) checklist `243` (done) + note `244`.
