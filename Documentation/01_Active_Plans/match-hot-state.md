# Match Hot State (Flutter ↔ Dart)

**Status:** Stage 2 practice stub complete — polish + later gameplay remain  
**Created:** 2026-08-05  
**Last Updated:** 2026-08-05

Related: [match-setting-core-flow.md](match-setting-core-flow.md) · [core-match-loop.md](core-match-loop.md) · [catalog-hot-reload.md](catalog-hot-reload.md) · [EXAMPLE_MODULE.md](../03_Base/EXAMPLE_MODULE.md) · [DART_STATE_SYSTEM.md](../03_Base/DART_STATE_SYSTEM.md) · [Flutter STATE_SYSTEM.md](../03_Base/Flutter/STATE_SYSTEM.md) · [ERROR_SYSTEM.md](../03_Base/ERROR_SYSTEM.md) · [WS_SYSTEM.md](../03_Base/WS_SYSTEM.md) · [PYTHON_DART_BACKEND.md](../03_Base/PYTHON_DART_BACKEND.md)

**Charts:** [match-setting-flow](../02_FlowCharts/charts/match_flow/match-setting-flow.html) · [match-state-flow](../02_FlowCharts/charts/dart_backend/state/match-state-flow.html) · [backend-state-split](../02_FlowCharts/charts/base/backend-state-split.html)

## Objective

Replace Play’s `_runMatchSsot` stub with a real **module-owned hot match store** on Dart, synced to Flutter over authuser WS. Dart is gameplay SSOT for the live match; FastAPI catalog remains definition SSOT; durable rewards stay out of scope.

**Player matching / matchmaking stays a stub** — practice create (human caller + AI seat) exercises create → snapshot → end → leave.

## Architecture rules (non-negotiable)

Align with architecture-align and error-sys rules:

1. **Modules + registry** — `match` module on Dart + Flutter (forked from `example_module`). Wire via `module_registry` only.
2. **Contracts** — core `RoomRegistry` / `BroadcastHub` / `WsConnectionContext`; no parallel session or id systems.
3. **Auth** — Dart WS `authuser` JWT; FastAPI catalog freeze via **`POST /service/catalog/designs`** + `X-Service-Key`.
4. **Errors** — `AppError` / `{ok, error}`; codes `match/…` and `catalog/…`. Flutter: `ApiError` via WS envelope (policy mapping still open — see below).

## Role split

| Layer | Owns |
|-------|------|
| **FastAPI catalog** | Design/slammer JSON on disk; authuser reads for Flutter; **service batch** for Dart |
| **Dart MatchStore** | Live match snapshot + **per-match frozen catalog** in process memory |
| **Flutter** | MatchFlow pipeline + mirror of wire snapshot |
| **IDs** | `userId` ↔ `connectionId` only |

## Wire channels (authuser)

| Channel | Role |
|---------|------|
| `match/create` | Practice stub create + catalog freeze + room subscribe |
| `match/join` | Rejoin seat by `matchId` |
| `match/leave` | Unsubscribe; empty room ends match |
| `match/end` | Caller ends match → `phase: ended` |
| `match/state` | Broadcast channel for full snapshot pushes |

WS handlers may be async (`FutureOr`) so create can await freeze.

## Catalog freeze

**Rule:** Catalog SSOT = FastAPI disk. Active match truth for physics = Dart per-match freeze **once at init**. Do not reload mid-match.

`POST /service/catalog/designs` body `{ "ids": ["…"] }` — fail-closed if any id missing. Returns `{ designs: { id: design } }` with `artworkPrompt` stripped + `catalogVersion`.

Dart calls this through module-owned [`MatchCatalogClient`](../../app_codebase/dart_bkend_base_02/bin/modules/match/match_catalog_client.dart) (not a method on core `FastApiServiceClient` — keeps core free of match imports).

## Player matching — stub

Practice stub only. Real matchmaking / invite / event fill = later.

## Gaps (remaining)

1. ~~`/service/catalog/*`~~ — **done** (`POST /service/catalog/designs`)
2. **Flutter SharedPrefs catalog hydrate** — optional, separate
3. **No mid-match catalog reload** — still forbidden
4. **Arena content catalog** — `arenaId` string only
5. **Piece physics on Arcori** — add to catalog when designed
6. Real matchmaking; full slam UI; durable rewards
7. **Flutter `error_policy` for `match/…`** — create/end failures currently log/timeout in `_runMatchSsot`; not yet branched via `actionForApiError`
8. **Dart live WS integration test** — store/service unit tests exist; no `match_*_ws_test` like `example_module_ws_test`

## Implementation steps

### A — FastAPI service catalog ✅

- [x] `POST /service/catalog/designs` batch by `internalId[]`
- [x] Reuse loader; omit `artworkPrompt`; include `catalogVersion`
- [x] Fail-closed missing ids (`catalog/not_found`)
- [x] Unit tests in `tests/modules/catalog/test_catalog_service.py`
- [ ] Optional: HTTP-level TestClient asserting service key required (guard already covers all `service_*` routes)

### B — Dart match module ✅

- [x] `modules/match/` store, service, catalog client, WS, errors, app
- [x] Practice stub seats + `MatchRuntime.catalogById`
- [x] Channels: create / join / leave / end; broadcast `match/state`
- [x] Register in Dart `module_registry`
- [x] Tests: `match_store_test.dart`, `match_service_test.dart` (mocked HTTP freeze)
- [ ] Optional: process WS integration test (`match/create` over real Dart server)

### C — Flutter match mirror + Play wiring ✅ (core path)

- [x] `modules/match/` snapshot notifier + replay + `registerMatchState`
- [x] Wire `_runMatchSsot` (create → end → leave when Dart WS + auth available; skip otherwise)
- [x] Tests: `test/modules/match/match_notifier_test.dart`; play notifier still passes offline
- [ ] Map `match/…` WS failures through `ApiError` / `error_policy` (user-facing + retry)

### D — Docs / charts ✅

- [x] This plan + catalog-hot-reload note
- [x] match-setting + match-state flowchart sources updated + regenerated

## Current progress

Verified in codebase (2026-08-05):

| Area | Evidence |
|------|----------|
| Service catalog | `catalog_app.py` `service_post("/catalog/designs")` + `get_designs_batch` |
| Dart match | `bin/modules/match/*` registered in `module_registry.dart` |
| Flutter mirror | `lib/modules/match/*` + `registerMatchState` in Flutter `module_registry` |
| Play wiring | `play_notifier.dart` `_runMatchSsot` create/end/leave |
| Charts | `match-setting-flow` + `match-state-flow` sources rebuilt |

Stage 2 **practice path** is implemented. Matching, slam gameplay, and durable rewards remain out of scope.

## Next steps

1. Optional polish: `error_policy` for match WS errors; Dart WS integration test
2. Real matchmaking / type setup
3. Slam intents + table simulation using freeze
4. Match UI surface
5. FastAPI finalize / Match Summary

## Files modified

- `Documentation/01_Active_Plans/match-hot-state.md`
- `Documentation/01_Active_Plans/catalog-hot-reload.md`
- `Documentation/01_Active_Plans/match-setting-core-flow.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/02_FlowCharts/charts/match_flow/match-setting-flow.*`
- `Documentation/02_FlowCharts/charts/dart_backend/state/match-state-flow.*`
- `app_codebase/python_base_05/bin/modules/catalog/catalog_app.py`
- `app_codebase/python_base_05/bin/modules/catalog/catalog_service.py`
- `app_codebase/python_base_05/tests/modules/catalog/test_catalog_service.py`
- `app_codebase/dart_bkend_base_02/bin/modules/match/**`
- `app_codebase/dart_bkend_base_02/bin/modules/module_registry.dart`
- `app_codebase/dart_bkend_base_02/bin/core/ws/contracts/ws_message_contract.dart`
- `app_codebase/dart_bkend_base_02/bin/core/ws/ws_dispatcher.dart`
- `app_codebase/dart_bkend_base_02/bin/core/http/fastapi_service_client.dart`
- `app_codebase/dart_bkend_base_02/test/match_store_test.dart`
- `app_codebase/dart_bkend_base_02/test/match_service_test.dart`
- `app_codebase/flutter_base_06/lib/modules/match/**`
- `app_codebase/flutter_base_06/lib/modules/play/play_notifier.dart`
- `app_codebase/flutter_base_06/lib/modules/play/play_models.dart`
- `app_codebase/flutter_base_06/lib/modules/module_registry.dart`
- `app_codebase/flutter_base_06/test/modules/match/match_notifier_test.dart`

## Notes / decisions

- **Caller** — `callerUserId`
- **Full wire snapshots**; private freeze not on wire
- AI seat `ai:seat_1`; stub ids `ANM-TIG-GEN001-0001`, `ANM-WTI-GEN001-0002`, `SLM-STR-GEN001-0001`
- Play skips live SSOT when `ARCORI_DART_WS_URL` or auth token missing (unit tests)
- Catalog freeze client is **module-owned** (`MatchCatalogClient`) rather than extending core `FastApiServiceClient` (avoids core → match import)
