# Match arena from seated Arcori

**Status**: Completed (Gatherer on table)  
**Created**: 2026-09-06  
**Last Updated**: 2026-09-23

Related: [match-hot-state.md](match-hot-state.md) · [catalog-hot-reload.md](catalog-hot-reload.md) · [stub-match-arcori-selection.md](stub-match-arcori-selection.md)

## Objective

After seated Arcori are known on **Quick Start** and **Invite**, pick a Velora arena from `01_regions.json` and paint that image as the match background. In the same pick, stamp a non-player **Gatherer** Arcori from that region **onto `table.pieces`** as a seatless disc.

**Not this pass:** Special Event (separate arena rules later). Practice stays on the stub `arenaId` (no catalog pick, no Gatherer).

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
5. **Table piece:** `pieceId=p_gatherer`, empty `ownerUserId`, **no `seatIndex`** (not a `MatchSeat`). Restack orders seat discs by `seatIndex`, then Gatherer on top. Flips score to the slamming player like any other disc.

**Seat uniqueness** (upstream `select_arcori` / `select_for_seats`): no duplicate Arcori ids across seats; Gatherer also excludes those ids.

## Architecture

| Layer | Owns |
|-------|------|
| FastAPI catalog | `select_arena_for_arcori_ids` — region counts + RNG arena + Gatherer; `select_for_seats` unique ids |
| Dart match room | After `select_arcori`, if `matchTypeUsesArcoriRegionArena`: `POST /service/catalog/select_arena` for arena image. **Gatherer stamped only when `matchTypeIncludesGatherer`** (`quickStart` / `invite`) — Special Event never gets `gathererArcoriId` / `p_gatherer` even if catalog returns one. |
| Flutter | Paints arena + stack (Gatherer included when present); `MatchPieceView.seatIndex` nullable / `isGatherer` |
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
- [x] Gatherer as seatless `table.pieces` entry (`p_gatherer`) + restack + tests

## Current Progress

Shipped: FastAPI arena + Gatherer pick; Dart Quick Start / Invite stamp + freeze + **seatless table piece**; Flutter parses nullable `seatIndex` / `isGatherer`.

## Next Steps

Special Event arena rules (separate). Optional Gatherer chrome label on the match surface (visual only).

## Files Modified

- `app_codebase/python_base_05/bin/modules/catalog/catalog_select.py`
- `app_codebase/python_base_05/bin/modules/catalog/catalog_app.py`
- `app_codebase/python_base_05/tests/modules/catalog/test_catalog_select.py`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_models.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_catalog_client.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_service.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/match_store.dart`
- `app_codebase/dart_bkend_base_02/bin/modules/match/table_pieces.dart`
- `app_codebase/dart_bkend_base_02/test/match_service_test.dart`
- `app_codebase/dart_bkend_base_02/test/matchmaking_service_test.dart`
- `app_codebase/dart_bkend_base_02/test/slam_resolver_test.dart`
- `app_codebase/flutter_base_06/lib/modules/match/state/match_snapshot_state.dart`
- `app_codebase/flutter_base_06/lib/modules/match/input/slam_resolver.dart`
- `app_codebase/flutter_base_06/test/modules/match/match_notifier_test.dart`

## Notes

- Fail closed: catalog/network errors keep stub `arena_velora_plaza` and no background image; empty Gatherer pool omits the field (and no table piece).
- Invite (2 seats): 2 same → that region; 2 different → random region + arena (rule 2).
- Authuser `select_arena` is available for later clients; Flutter practice does not call it.
- Rematch re-runs arena + Gatherer with new seated picks (same as arena today).
- Product name is **Gatherer** (not “host” — lore already avoids host for lobby authority / Caller).

## Case study

Arena + Gatherer live in FastAPI catalog; match snapshot carries `arenaId` + `arenaImageUrl` + optional `gathererArcoriId`. When present, Gatherer is also a seatless `table.pieces` disc (`p_gatherer`). Seat Arcori ids are unique across the table and vs Gatherer.

## Task Manager

App Dev checklist: Gatherer table piece — synced with this plan update.
