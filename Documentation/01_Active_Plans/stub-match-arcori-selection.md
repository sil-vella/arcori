# Stub Match Arcori Selection

**Status:** Completed (updated)  
**Created:** 2026-08-21  
**Last Updated:** 2026-09-12

Related: [ws-matchmaking-modes.md](ws-matchmaking-modes.md) · [match-hot-state.md](match-hot-state.md) · [kin-creation.md](kin-creation.md) · [Tech Spec](../Game_Specific/Arcori_Technical_Specification_v0.4.md) · catalog `04_selection_weights.json`

## Objective

After players are seated in the online match stub, pick one Arcori per seat from that player's accessible **circulating** list using design **`selectionWeight`** × region standing (`04_selection_weights.json`). Weight failures fall back to random **among that player's circulating access only** — never the global catalog. Log picks. No slam or other match-rule changes.

## Flow

```text
matchmaking promote → startFromLobby
  → POST /service/catalog/select_arcori (seat order)
  → set seat.arcoriIds
  → existing catalog freeze + stub match
```

Practice stays Flutter-only (loadout unchanged).

## Implementation Steps

- [x] `catalog_loader` meta key `selection_weights` → `04_selection_weights.json`
- [x] `catalog_select.select_for_seats` + `LOGGING_SWITCH` customlog
- [x] `POST /service/catalog/select_arcori`; candidates from body or `player_design_access`
- [x] Filter candidates to circulating (Active) designs only
- [x] Weighted pick; fallback random **only** within player circulating access
- [x] Empty player access → empty `arcoriId` (Dart Tiger / White Tiger stub) — no catalog-wide random
- [x] Dart `MatchCatalogClient.selectArcori` + `startFromLobby` apply; HTTP fail → stubs
- [x] Python + Dart unit tests
- [x] Smoke: invite match both seats `source=weighted` after starter access granted
- [x] Resolve candidate designs via `get_design` (static + player Kin file/DB) so claimed Kin stays in the pre-match pool; log pool `ids=`

## Current Progress

Complete. Candidate source of truth is DB `player_design_access`. Design docs resolve through catalog `get_design` (not static-loader-only), so Kin and other player circulating stock are selectable. Trove mints remain ownership-only (not access) and stay out of the match pool.

## Next Steps

- Optional: stamp Lottie face on match freeze for Kin picks (match disc face path).

## Files Modified

- Python: `catalog_select.py`, `catalog_app.py`, `catalog_loader.py`, `avari_service.list_design_access_ids`
- Dart: `match_catalog_client.dart`, `match_service.dart` (`startFromLobby`)
- Tests: `test_catalog_select.py`, `match_service_test.dart`

## Notes

- Empty player circulating access → empty `arcoriId` (Dart still applies Tiger / White Tiger stub for that seat). Random fallback never uses the full circulating catalog.
- Pre-match pool = all circulating access rows that resolve Active; pick uses existing rarity × region weights.
None on this plan. Next app build was stub turn stages — see [stub-match-turn-stages.md](stub-match-turn-stages.md); then weighted slam / real turns.

## Files Modified

- Python: `catalog_select.py`, `catalog_app.py`, `catalog_loader.py`, `avari_service.list_design_access_ids`
- Dart: `match_catalog_client.dart`, `match_service.dart`
- Data: `data/04_selection_weights.json`
- Tests: `tests/modules/catalog/test_catalog_select.py`, Dart match / matchmaking tests
- Docs: Tech Spec pairing note; this plan; master plan; case study decision row

## Notes

- Match pairing SSOT is `04_selection_weights.json`, not per-design `selectionWeight`.
- Access ids that are retired / missing from catalog are dropped before scoring.
- Empty player circulating access → empty `arcoriId` (Dart still applies Tiger / White Tiger stub for that seat). Random fallback never uses the full circulating catalog.
- First-time “10 random Common access” grant is still **not** implemented (only admin seed + manual grants); tracked under first-time player flow.

## Case study

`03_CASE_STUDY.md` — Major decisions: Match Arcori pick after seats (player access only; no global circulating fallback).

## Task Manager

App Dev (task `32`): checklist **Stub match Arcori selection (Python weights + Dart startFromLobby)** — item `144` checked; completion note `145` added.
