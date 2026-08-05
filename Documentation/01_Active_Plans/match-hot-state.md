# Match Hot State (Flutter ↔ Dart)

**Status:** Spec locked — ready to implement  
**Created:** 2026-08-05  
**Last Updated:** 2026-08-05

Related: [match-setting-core-flow.md](match-setting-core-flow.md) · [core-match-loop.md](core-match-loop.md) · [catalog-hot-reload.md](catalog-hot-reload.md) · [EXAMPLE_MODULE.md](../03_Base/EXAMPLE_MODULE.md) · [DART_STATE_SYSTEM.md](../03_Base/DART_STATE_SYSTEM.md) · [Flutter STATE_SYSTEM.md](../03_Base/Flutter/STATE_SYSTEM.md) · [ERROR_SYSTEM.md](../03_Base/ERROR_SYSTEM.md) · [WS_SYSTEM.md](../03_Base/WS_SYSTEM.md) · [PYTHON_DART_BACKEND.md](../03_Base/PYTHON_DART_BACKEND.md)

**Charts:** [match-setting-flow](../02_FlowCharts/charts/match_flow/match-setting-flow.html) · [match-state-flow](../02_FlowCharts/charts/dart_backend/state/match-state-flow.html) · [backend-state-split](../02_FlowCharts/charts/base/backend-state-split.html)

## Objective

Replace Play’s `_runMatchSsot` stub with a real **module-owned hot match store** on Dart, synced to Flutter over authuser WS. Dart is gameplay SSOT for the live match; FastAPI catalog remains definition SSOT; durable rewards stay out of scope.

**Player matching / matchmaking stays a stub** — practice (or single-seat create) is enough to exercise join → snapshot → leave/end.

## Architecture rules (non-negotiable)

Align with [architecture-align-rule](../../.cursor/rules/architecture-align-rule.mdc) and [error-sys-rule](../../.cursor/rules/error-sys-rule.mdc):

1. **Modules + registry** — new `match` module on Dart + Flutter (fork `example_module`; do not extend it). Wire via `module_registry` only.
2. **Contracts** — use core `RoomRegistry` / `BroadcastHub` / `WsConnectionContext`; no parallel session or id systems.
3. **Auth** — Dart WS `authuser` JWT; FastAPI catalog freeze via **`/service/catalog/*`** + `X-Service-Key`. No alternate auth.
4. **Errors** — `AppError` / `{ok, error: {code, message}}`; module codes `match/…` and extend `catalog/…` for service fetch failures. Flutter: `ApiError` + `error_policy` (no hardcoded strings).

## Role split

| Layer | Owns |
|-------|------|
| **FastAPI catalog** | Design/slammer JSON on disk; authuser reads for Flutter; **new service-tier batch fetch** for Dart |
| **Dart MatchStore** | Live match snapshot + **per-match frozen catalog** (sim stats) in process memory |
| **Flutter** | MatchFlow pipeline + mirror of wire snapshot; art/name via existing Velora/catalog HTTP (not embedded in every WS tick) |
| **IDs** | `userId` (JWT `sub`) ↔ `connectionId` (WS session) already on `WsConnectionContext` + `RoomRegistry.userIdFor` — **no new player/match-player ids** |

```text
Flutter (Play / match notifier)
  → WS authuser match/* 
  → Dart MatchService / MatchStore
       → (on match init) FastAPI POST/GET /service/catalog/…  (batch designs)
       → freeze into MatchRuntime.catalogById
  → broadcast full MatchSnapshot (version++)
  → Flutter replace local mirror
```

## Wire snapshot (full object each broadcast)

Prefer **full snapshots** on the wire (same idea as `example_module`: small intents in, full truth out). Clients replace local state when `version` is newer.

```json
{
  "matchId": "m_…",
  "version": 1,
  "phase": "playing",
  "round": 1,
  "roundsTotal": 2,
  "arenaId": "arena_velora_plaza",
  "callerUserId": "usr_…",
  "matchType": {
    "code": "practice"
  },
  "seats": [
    {
      "userId": "usr_…",
      "seatIndex": 0,
      "kind": "human",
      "score": 0,
      "connected": true,
      "arcoriIds": ["ANM-TIG-GEN001-0001"],
      "slammerId": "SLM-STR-GEN001-0001"
    }
  ],
  "table": { "pieces": [] },
  "active": null,
  "lastEvent": null,
  "result": null
}
```

### Field notes

| Field | Notes |
|-------|--------|
| `matchType` | **Object** with `code` (`practice` \| `quickStart` \| `specialEvent` \| `invite`) + type-specific keys (e.g. `eventId`, `eventName`, `inviteId`) |
| `callerUserId` | Who called the match (arena / lobby authority). Included in snapshot. |
| `arenaId` | Chosen pre-match; kept in snapshot for bg/FX. |
| `seats[]` | Lean only — no username/rank. `arcoriIds[]`, `slammerId`, `kind` human\|ai. |
| `result` | `null` until `phase: "ended"`. |

**Not on the wire (Dart private):** `MatchRuntime.catalogById` freeze used for physics / slam resolution.

### `matchType` examples

```json
{ "code": "practice" }
{ "code": "quickStart", "entryCostCaps": 1 }
{ "code": "specialEvent", "eventId": "evt_…", "eventName": "Summer Slam", "rulesetId": "rules_event_v1" }
{ "code": "invite", "inviteId": "inv_…", "maxSeats": 4 }
```

## Catalog freeze (match init)

**Rule:** Catalog SSOT = FastAPI disk. Active match truth for physics = **Dart per-match freeze loaded once at init**. Do **not** reload catalog mid-match.

1. On match create / loadout lock, Dart calls FastAPI **`/service/catalog/…`** (batch by `internalId`s from seats).
2. Store sim-critical fields in `MatchRuntime.catalogById` (slammer `gameplayAttributes` / economy as needed; Arcori piece rules when defined).
3. Slam / rule resolution reads **only** the freeze — never client-supplied stats.

Authuser catalog remains for Flutter UI (images via `imageUrl` / `/catalog-media`).

## Player matching — stub

| In this plan | Stub / later |
|--------------|--------------|
| Create/join a match room with caller + fixed/stub seats (e.g. practice: human + optional AI seat) | Real matchmaking queue, invite flow, event lobby fill |
| `typeSetup` may no-op or set hardcoded practice loadout | Per-type economy checks, arena picker UI, invite UX |

Matching stub must still produce a valid `MatchSnapshot` + freeze path so Stage 2 is testable end-to-end.

## Predictive client presentation

- Flutter may start slam / FX animations on intent (**presentation only**).
- Scores, flips, win/loss come only from Dart broadcasts; reconcile animation to `lastEvent` / snapshot.
- Do not optimistically mutate authoritative seat scores.

## Scope

| In | Out (later / other plans) |
|----|---------------------------|
| Dart `match` module: store, WS join/state/leave (or create), room broadcast, errors | Real matchmaking / invite / event fill |
| Flutter match notifier + replay + `AppStateSink.onWsReady`; wire `_runMatchSsot` | Full match gameplay UI / celebration / Match Summary |
| Full snapshot sync + terminal `phase: ended` → Play idle | FastAPI durable rewards / mastery / gold |
| FastAPI **`/service/catalog`** batch fetch for freeze | Flutter SharedPrefs catalog hydrate (optional, separate — see catalog plan) |
| Tests: store, WS, freeze, Flutter mirror | Mid-match catalog hot-reload into active matches (**forbidden**) |

## Gaps (explicit)

1. **`/service/catalog/*` does not exist yet** — only authuser catalog today. Add service-tier design (prefer **batch by ids**) for Dart match init. Reuse `catalog_loader` / service strip rules; guard with `service` tier + `SERVICE_KEY`.
2. **Flutter SharedPrefs catalog hydrate** — optional and **separate** from this plan ([catalog-hot-reload.md](catalog-hot-reload.md) out-of-scope list). Match UI can fetch needed designs over authuser HTTP / existing Velora client when rendering.
3. **No mid-match catalog reload** — balance patches must not change an in-flight freeze. New matches pick up new catalog on next init.
4. **Arena content catalog** — `arenaId` string in snapshot now; arena definitions / media can land later like other content.
5. **Piece physics fields on Arcori** (e.g. weight) — add to catalog when designed; then include in freeze. Slammer `gameplayAttributes` already exist in `slammers.json`.

## Implementation steps

### A — FastAPI service catalog (prerequisite for freeze)

- [ ] Add `/service/catalog/designs` (or equivalent) batch fetch by `internalId[]`
- [ ] Reuse loader; omit `artworkPrompt`; return fields Dart needs for freeze (+ `catalogVersion` / theme doc version if available)
- [ ] Register in `module_registry`; `catalog/…` errors for not_found / invalid_query / load_failed
- [ ] Tests: service key required; batch happy path; missing id behavior

### B — Dart match module

- [ ] Fork `example_module` → `modules/match/` (store, service, WS handlers, errors, app registration)
- [ ] Models: `MatchSnapshot`, `MatchSeat`, `MatchType` object, `MatchRuntime` (private freeze map)
- [ ] `MatchStore`: create (stub seats), apply join/leave, bump `version`, end match
- [ ] On create/init: call FastAPI service catalog → fill `catalogById`; fail match create with `match/catalog_freeze_failed` (or map catalog codes) if freeze fails
- [ ] WS channels (authuser): e.g. `match/join`, `match/leave`, `match/state` (and/or create) — broadcast **full** snapshot via `BroadcastHub` + `RoomRegistry`
- [ ] Authorize seats by `ctx.userId`; route by `ctx.connectionId` (existing map only)
- [ ] Register state reset + WS + errors in Dart `module_registry`
- [ ] Tests: store versioning, room broadcast, freeze mocked service client, leave/end

### C — Flutter match mirror + Play wiring

- [ ] Match state models + notifier + optional replay (`example_module` pattern)
- [ ] `registerMatchState(AppStateSink)` — `onWsReady` / reconnect subscribe as needed
- [ ] Wire `MatchFlowNotifier._runMatchSsot`: connect Dart WS → join/create stub match → watch until `phase == ended` → tear down → continue pipeline to idle
- [ ] Map `match/…` (and catalog-related) failures via `ApiError` / `error_policy`
- [ ] Tests: notifier apply snapshot by version; router dispatch; Play smoke with mocked WS if feasible

### D — Docs / charts

- [ ] Update [match-setting-core-flow.md](match-setting-core-flow.md) Stage 2 to point here as detail SSOT
- [ ] Update match-setting + match-state flowcharts/guides when channels land
- [ ] Note service catalog in [catalog-hot-reload.md](catalog-hot-reload.md) when implemented

## Current progress

Spec locked in planning (snapshot shape, caller, arena, matchType object, seats with `arcoriIds[]` + `slammerId`, full snapshots, catalog freeze via service tier, matching stubbed). **No implementation yet.**

## Next steps

1. Implement **A — `/service/catalog` batch** (unblocks freeze).
2. Implement **B — Dart match module** with practice stub create + freeze.
3. Implement **C — Flutter mirror** + `_runMatchSsot` wiring.
4. Refresh charts/guides.

## Files modified

*(Populate as implementation proceeds.)*

- `Documentation/01_Active_Plans/match-hot-state.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/01_Active_Plans/match-setting-core-flow.md`

## Notes / decisions

- **Caller** (not steward/host) — `callerUserId` for who called the match.
- **Full wire snapshots**; optional deltas only if measured need later — always keep full resync on join.
- **AI seats:** e.g. `userId: "ai:seat_N"`, `kind: "ai"` — not real accounts.
- Practice: caller = human; progression/economy still later (GDD: practice free, no progression).
- Post-match FastAPI finalize remains future ([core-match-loop.md](core-match-loop.md)); terminal snapshot is enough for Play to leave `inMatch`.
