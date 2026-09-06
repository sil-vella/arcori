# Catalog Hot-Reload (Backend)

**Status:** Implemented (v1 read API + media + Flutter Velora browse)  
**Created:** 2026-07-24  
**Last Updated:** 2026-09-06

Related: [Tech Spec](../Game_Specific/Arcori_Technical_Specification_v0.4.md) · [arcori-standings-surface.md](arcori-standings-surface.md)

**Chart + plain English guide:** [catalog-hot-reload-flow](../02_FlowCharts/charts/base/catalog-hot-reload-flow.html) · [guide](../02_FlowCharts/charts/base/catalog-hot-reload-flow.guide.html)

## Objective

Serve Arcori catalog JSON from `bin/modules/catalog/data/` over existing **authuser** HTTP without process restart when files are added or edited; serve design art for Velora / Detail.

## Loader

- `catalog_loader.py` — per-file `(mtime_ns, size)` memory cache; series dir scan for theme JSON
- Override root: `CATALOG_DATA_ROOT` or test `set_data_root_override`
- Debug compose mounts `bin` → live file edits visible in container
- Catalog artwork: `assets/images/arcori` → `/data/catalog-media` (`CATALOG_MEDIA_ROOT`, `:ro`)
- Region arena art: `assets/images/velora/{region-slug}/{arenaId}.webp` → `/data/catalog-velora` (`CATALOG_VELORA_MEDIA_ROOT`, sibling bind at the same host level as `arcori`). Public URL `/catalog-media/velora/…` via a dedicated StaticFiles mount (do not nest a bind under the `:ro` Arcori tree).
- Path convention: `series/{series_slug}/{theme_slug}.json` and art `/{series_slug}/{theme_slug}/{internalId}.webp` (e.g. `genesis/animals/…`)

## Media (public)

- FastAPI `StaticFiles` mount: `GET /catalog-media/*` from `CATALOG_MEDIA_ROOT` (same public posture as `/media` avatars)
- Derived client field `imageUrl`: `/catalog-media/{series_slug}/{theme_slug}/{internalId}.webp`
- Uses document-level `series` (`Genesis` → `genesis`) + design/theme name — not design’s `"Genesis Series"` display string
- Index/theme/design also expose `seriesKey` for grouping

## Endpoints (authuser)

Router is exact-match (no path params) — ids via query:

| Method | Path | Query | Purpose |
|--------|------|-------|---------|
| GET | `/authuser/catalog/meta` | — | Themes, regions, kin, rarities |
| GET | `/authuser/catalog/index` | `series`, `theme`, `subtheme`, `circulating`, `limit`, `offset` | Velora list (`circulating=1` → `worldState == Active`) |
| GET | `/authuser/catalog/theme` | `code` or `theme_code` | Full theme document |
| GET | `/authuser/catalog/design` | `id` or `internal_id` | Single design |
| POST | `/authuser/catalog/select_arena` | body `{ "arcoriIds": ["…"] }` | Same pick as service (available; practice does not call it) |

Client payloads omit `artworkPrompt`. Envelope: `{ok, data}` / `{ok, error}` with `catalog/*` codes.

## Endpoints (service)

| Method | Path | Body | Purpose |
|--------|------|------|---------|
| POST | `/service/catalog/designs` | `{ "ids": ["…"] }` | Batch designs for Dart match freeze (fail-closed) |
| POST | `/service/catalog/select_arcori` | `{ "seats": [...] }` | Weighted Arcori pick after seats exist |
| POST | `/service/catalog/select_arena` | `{ "arcoriIds": ["…"] }` | Arena from seated regions (Quick Start / Invite) |

## Flutter (Velora slice)

- Module `lib/modules/velora/` — index (theme → series) + Arcori Detail via `ArcoriCylinder` (catalog art + color rim)
- Paths: `/velora`, `/velora/arcori?id=`
- Uses authuser catalog GETs + catalog `imageUrl` / `color`

## Module files

- `catalog_app.py`, `catalog_service.py`, `catalog_loader.py`, `catalog_errors.py`
- Wired in `module_registry.py`; media mount in `core/http/service/routes.py`
- Tests: `tests/modules/catalog/`

## Out of scope (still)

- Standings / mastery / Trove
- Flutter SharedPrefs catalog hydrate (optional; separate from match)
- Postgres catalog sync

## Related follow-on

- **`POST /service/catalog/designs`** — implemented for [match-hot-state.md](match-hot-state.md) (Dart freezes slammer/Arcori stats at match init; service key only).
