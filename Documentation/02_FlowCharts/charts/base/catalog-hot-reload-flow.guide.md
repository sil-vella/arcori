# Catalog hot-reload flow

This chart shows how the FastAPI **catalog** module serves Velora design JSON from disk with a **mtime memory cache**, so adding or editing theme files does not require a server restart.

## Concepts

| Piece | Role |
|-------|------|
| **authuser** | All catalog reads need a Bearer access JWT (same as notifications / profile) |
| **Exact-match router** | Paths are fixed strings; theme/design ids are **query params** (`code`, `id`) |
| **Loader cache** | Per worker: `(mtime_ns, size) → parsed JSON`; mismatch → re-read file |
| **Index scan** | `GET …/catalog/index` lists `data/series/**/*.json` using folder mtimes so **new** theme files appear |
| **SSOT** | Files under `bin/modules/catalog/data/` — not Postgres for v1 |

## Endpoints

| Full URL | Purpose |
|----------|---------|
| `GET /authuser/catalog/meta` | Themes, regions, kin, rarities |
| `GET /authuser/catalog/index` | Velora list-everything (optional `series` / `theme` / `subtheme` / `limit` / `offset`) |
| `GET /authuser/catalog/theme?code=ANM` | One theme document |
| `GET /authuser/catalog/design?id=ANM-TIG-GEN001-0001` | One design |

Responses use `{ok: true, data: …}` and omit `artworkPrompt`. Errors use `catalog/not_found`, `catalog/invalid_query`, `catalog/load_failed`.

## Step-through

1. Startup registers `catalog` errors and authuser routes via `module_registry`.
2. Client calls an authuser catalog URL with Bearer token.
3. `authuser_guard` verifies JWT; `catalog_app` calls `catalog_service`.
4. Service asks the loader for meta, a theme file, a design, or a full series scan.
5. Loader stats the file (or series folders). Same fingerprint → cached object; else read JSON and refresh cache.
6. Service strips `artworkPrompt` and returns `json_ok`.
7. After you add/edit a JSON file on the mounted `bin` volume, the **next** request that touches that path (or index) picks up the change — per worker.

## Copy-paste examples

```bash
# After login — paste access_token
TOKEN=…

curl -s http://127.0.0.1:8000/authuser/catalog/meta \
  -H "Authorization: Bearer $TOKEN" | jq .

curl -s 'http://127.0.0.1:8000/authuser/catalog/index?theme=Animals&limit=5' \
  -H "Authorization: Bearer $TOKEN" | jq .

curl -s 'http://127.0.0.1:8000/authuser/catalog/theme?code=ANM' \
  -H "Authorization: Bearer $TOKEN" | jq '.data.themeCode, (.data.designs|length)'

curl -s 'http://127.0.0.1:8000/authuser/catalog/design?id=ANM-TIG-GEN001-0001' \
  -H "Authorization: Bearer $TOKEN" | jq .
```

```python
# Unit tests use a temp data root
from modules.catalog import catalog_loader as loader
loader.set_data_root_override(tmp_path / "data")
```

## Try it locally

1. Start FastAPI debug compose (`bin` is bind-mounted).
2. Obtain a token (`/public/auth/login` or guest bootstrap).
3. Hit `/authuser/catalog/index`.
4. Add `bin/modules/catalog/data/series/genesis/fashion.json` and call index again — new theme should appear without restarting the API container.

## Related

- Active plan: [catalog-hot-reload.md](../../../01_Active_Plans/catalog-hot-reload.md)
- Tech Spec: [Arcori_Technical_Specification_v0.4.md](../../../Game_Specific/Arcori_Technical_Specification_v0.4.md)
- Auth tier chart: [security-auth-flow](security-auth-flow.html)
- Errors: [error-handling-flow](error-handling-flow.html) · [ERROR_SYSTEM.md](../../../03_Base/ERROR_SYSTEM.md)
