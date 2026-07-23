# arcori — example_module (cross-stack)

One **reference module** named `example_module` on all three stacks. It shows how tiered state fits together without game/match gameplay logic.

| Stack | Path | Hot state | Durable / cache |
|-------|------|-----------|-----------------|
| **Flutter** | `lib/modules/example_module/` | `exampleModuleProvider` + `example/*` WS replay | — |
| **Dart** | `bin/modules/example_module/` | `ExampleModuleStore` + `example/state` WS | — |
| **FastAPI** | `bin/modules/example_module/` | — | `example_module_records` + Redis read-through |

**State system docs:** [DART_STATE_SYSTEM.md](DART_STATE_SYSTEM.md) · [PYTHON_STATE_SYSTEM.md](PYTHON_STATE_SYSTEM.md) · [Flutter/STATE_SYSTEM.md](Flutter/STATE_SYSTEM.md)

**Chart:** [example-module-state-flow](../02_FlowCharts/charts/dart_backend/state/example-module-state-flow.html) · [backend-state-split](../02_FlowCharts/charts/base/backend-state-split.html)

## Wire format

**Dart WS** (authuser tier), channel `example/state`:

```json
{"type":"event","channel":"example/state","payload":{"message":"hello","record":false}}
```

Response envelope: `{ok, data}` with updated `{revision, message}` in payload.

**FastAPI service** (Dart → Python, optional when `record: true`):

```http
POST /service/example_module/record
X-Service-Key: …
{"user_id":"…","payload":{"revision":2,"message":"hello"}}
```

**FastAPI authuser reads:**

- `GET /authuser/example_module/recent` — recent rows for user
- `GET /public/example/cached` — Redis read-through demo (unchanged path)

## Lifecycle

1. Flutter dev-login → JWT
2. WS Demo or Example module screen connects to Dart `ws/authuser`
3. Send `example/state` event → Dart bumps in-memory revision
4. Optional `record: true` → Dart calls FastAPI service tier
5. Flutter `exampleModuleProvider` updates via `example/*` prefix handler + replay

## When you add a real feature

Copy `example_module/` to `your_feature/`, rename channels and models, keep the same patterns:

- Module-owned hot store on Dart (not in `core/state` unless shared transport)
- `session_scope()` + repository on Python
- `AppStateSink.onWsReady` + Riverpod notifier on Flutter

Do **not** extend `example_module` for production features — fork the folder.

## Flutter UI — bottom action bar

The example module demonstrates the screen-scoped bottom bar (not auth-gated; route is public like Home/Sample):

| File | Role |
|------|------|
| `lib/modules/example_module/example_module_bottom_nav.dart` | Scope `example_module` → `/example-module`; **Go to Home** action via `Nav.push` |
| `lib/modules/example_module/example_module_screen.dart` | `ModuleScreenRegistrar` wraps AppBar + bottom nav |

Full guide: [Flutter/BOTTOM_NAV_REGISTRATION.md](Flutter/BOTTOM_NAV_REGISTRATION.md).

**Note:** WS Demo remains login-protected (`AppPaths.requiresAuth`); example module does not. Bottom bar visibility is not tied to dev login — only individual actions may use `visibleWhen`.

## Migration

Table `example_module_records` — migration `002_example_module_records`:

```bash
cd app_codebase/python_base_05
export DATABASE_URL=…
python3 bin/migrate.py
```

Skip migration if you only use Dart hot state and cache demo routes.

**Docker:** set `FASTAPI_SERVICE_URL=http://Arcori_api:8000` on the Dart service (see `.env.local.sample`) so `record: true` reaches FastAPI inside compose.

## Tests

| Stack | Test |
|-------|------|
| Dart | `test/example_module_store_test.dart`, `test/example_module_ws_test.dart` |
| Python | `test/test_example_module_service.py` |
| Flutter | `test/modules/example_module/example_module_notifier_test.dart`, `test/core/bottom_nav/bottom_nav_test.dart` |
