# Platform shell boundary — extraction complete

This repo is a **neutral FastAPI + PostgreSQL + Docker template** (`arcori` branding) with optional **Dart realtime** and **Flutter** client shells.

**Related:** [PRODUCTION_SYSTEM.md](../03_Base/PRODUCTION_SYSTEM.md) · [PYTHON_DART_BACKEND.md](../03_Base/PYTHON_DART_BACKEND.md) · [WS_SYSTEM.md](../03_Base/WS_SYSTEM.md) · [SECURITY_SYSTEM.md](../03_Base/SECURITY_SYSTEM.md)

---

## Platform shell (kept)

| Area | Path / notes |
|------|----------------|
| FastAPI HTTP + WS | `python_base_05` — `/ws/public`, `/ws/authuser`, `/ws/service` |
| Dart game server | `dart_bkend_base_02` — same WS protocol on `:8080` |
| Flutter client | `flutter_base_06` — `ws_demo` module |
| Docker | `Arcori_api`, `Arcori_dart`, Postgres, Adminer (`:8081`), Caddy |
| Auth / service key | Shared `JWT_*` + `SERVICE_KEY` across Python and Dart |

---

## Naming convention (`arcori`)

| Case / pattern | Form | Used for |
|----------------|------|----------|
| **SCREAMING_SNAKE** env prefix | `ARCORI_*` | `.env.*`, `os.environ`, docs |
| **PascalCase + `_`** Docker service | `Arcori_postgres`, `Arcori_api`, `Arcori_dart`, … | Compose keys, hostnames |
| **snake_case** compose project | `arcori` | Top-level `name:` in compose |
| Flutter dart-define | `ARCORI_API_WS_URL`, `ARCORI_DART_WS_URL`, `ARCORI_API_REST_URL` | `ws_config.dart` |

---

## Quick start

```bash
cp .env.local.sample .env.local
docker compose --env-file ../.env.local -f docker/docker-compose.debug.yml up -d --build
curl -s http://127.0.0.1:8000/health | jq .
curl -s http://127.0.0.1:8080/health | jq .
```

Flutter WS demo: `wfrun` → `automation/frontend/launch_chrome.sh` (loads `.env.dart.defines.local`) → drawer **WS Demo** → dev-login → Connect both WS.

---

## Forking for a new product

Replace `ARCORI_*` / `Arcori_*` / `arcori` with your product prefix using the same case rules. See [wfstart.md](../00_System_Wide/wfstart.md).
