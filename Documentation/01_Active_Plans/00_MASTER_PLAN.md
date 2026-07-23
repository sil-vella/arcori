# Arcori — documentation index

Neutral **FastAPI + PostgreSQL + Dart + Flutter** template (`arcori` branding). Backends run via **Docker Compose** locally and on the VPS.

## Quick start (local)

```bash
cp .env.local.sample .env.local
cp .env.dart.defines.local.sample .env.dart.defines.local
cd docker
docker compose --env-file ../.env.local -f docker-compose.debug.yml up -d --build
```

| Service | URL |
|---------|-----|
| FastAPI (REST + WS) | http://127.0.0.1:8000 |
| Dart (REST + WS) | http://127.0.0.1:8080 |
| Adminer | http://127.0.0.1:8081 |
| Postgres (host) | `127.0.0.1:5433` |

Flutter WS demo: `wfrun` → `automation/frontend/launch_chrome.sh` → drawer **WS Demo**.

## Repo layout

| Path | Role |
|------|------|
| `app_codebase/python_base_05/` | FastAPI — HTTP + WebSocket |
| `app_codebase/dart_bkend_base_02/` | Dart Shelf — HTTP + WebSocket |
| `app_codebase/flutter_base_06/` | Flutter client (`ws_demo`) |
| `docker/` | `docker-compose.debug.yml` (local), `docker-compose.yml` (prod) |
| `automation/frontend/` | Flutter launch scripts (`wfrun` frontend profile) |
| `automation/backend/` | Chart builder (`build_nav_and_charts.py`) |
| `automation/dashboard/` | wfrun browser GUI (`serve.py`) — alternative to CLI menu |

## Environment files

| File | Purpose |
|------|---------|
| `.env.local` / `.env.prod` | Backend secrets, DB, Caddy — loaded by compose |
| `.env.dart.defines.local` / `.env.dart.defines.prod` | Flutter `dart-define` keys — loaded by `wfrun` for `automation/frontend/*` |

See [wfsecrets.md](../00_System_Wide/wfsecrets.md) and [wfrun.md](../00_System_Wide/wfrun.md).

## Active infrastructure work

| Plan | Topic |
|------|--------|
| [01_TEMPLATE_INSTALLATION.MD](01_TEMPLATE_INSTALLATION.MD) | New product install: `wfstart` rename, secrets, edge drain, TLS, RBAC, VPN, smoke |
| [vps-wireguard-vpn-automation.md](vps-wireguard-vpn-automation.md) | New VPS, WireGuard VPN, prod automation only via VPN IP allowlist |
| [drain-maintenance-pipeline.md](drain-maintenance-pipeline.md) | Graceful drain (FastAPI/Dart app layer; edge in VPS repo) |
| [postgres-tls-in-transit.md](postgres-tls-in-transit.md) | PostgreSQL TLS in transit — align `automation/production/mongodb_tls` → Postgres + compose + clients |
| [postgres-rbac-verification.md](postgres-rbac-verification.md) | Verify and enforce least-privilege PostgreSQL roles (app / migrate / readonly) |
| [rate-limiting.md](rate-limiting.md) | Redis HTTP rate limits (global + auth + guest_register) |
| [refresh-token-rotation.md](refresh-token-rotation.md) | Refresh JWT rotation + Redis revocation / reuse detection |
| [guest-register-harden.md](guest-register-harden.md) | Guest domain rule + dedicated guest_register Redis bucket |
| [email-verification.md](email-verification.md) | Soft email verification (SMTP + Redis tokens) |

## Base system docs (`03_Base/`)

| Doc | Topic |
|-----|--------|
| [platform-shell-boundary.md](platform-shell-boundary.md) | What this template includes; naming convention |
| [WS_SYSTEM.md](../03_Base/WS_SYSTEM.md) | WebSocket tiers, demo + example_module |
| [EXAMPLE_MODULE.md](../03_Base/EXAMPLE_MODULE.md) | Cross-stack reference module |
| [DART_STATE_SYSTEM.md](../03_Base/DART_STATE_SYSTEM.md) | Dart state infrastructure |
| [PYTHON_STATE_SYSTEM.md](../03_Base/PYTHON_STATE_SYSTEM.md) | Python state infrastructure |
| [POSTGRES_RBAC.md](../03_Base/POSTGRES_RBAC.md) | PostgreSQL roles, split URLs, verify_rbac |
| [SECURITY_SYSTEM.md](../03_Base/SECURITY_SYSTEM.md) | JWT, service key, route tiers |
| [ERROR_SYSTEM.md](../03_Base/ERROR_SYSTEM.md) | Error catalog, HTTP/WS envelope |
| [PRODUCTION_SYSTEM.md](../03_Base/PRODUCTION_SYSTEM.md) | Gunicorn, Caddy, health, compose prod |
| [DRAIN_SYSTEM.md](../03_Base/DRAIN_SYSTEM.md) | App-layer drain before deploy / stop |
| [PYTHON_DART_BACKEND.md](../03_Base/PYTHON_DART_BACKEND.md) | FastAPI ↔ Dart coordination |

### Flutter client (`flutter_base_06/`)

| Doc | Topic |
|-----|--------|
| [NAVIGATION_SYSTEM.md](../03_Base/Flutter/NAVIGATION_SYSTEM.md) | go_router, drawer, `Nav`, `AppShell` |
| [DEEP_LINKS.md](../03_Base/Flutter/DEEP_LINKS.md) | Email-verify App Links + `.well-known` stubs |
| [APPBAR_WIDGET_REGISTRATION.md](../03_Base/Flutter/APPBAR_WIDGET_REGISTRATION.md) | `ShellAppBar`, toolbar slots |
| [BOTTOM_NAV_REGISTRATION.md](../03_Base/Flutter/BOTTOM_NAV_REGISTRATION.md) | `ShellBottomBar`, module bottom actions |
| [STATE_SYSTEM.md](../03_Base/Flutter/STATE_SYSTEM.md) | Riverpod, auth, WS state |

## Workflow commands (`~/bin`)

| Command | Doc |
|---------|-----|
| `wfrun` | [wfrun.md](../00_System_Wide/wfrun.md) |
| `wfstart` | [wfstart.md](../00_System_Wide/wfstart.md) |
| `wfcharts` | [wfcharts.md](../00_System_Wide/wfcharts.md) |

## Flowcharts

Source: `Documentation/02_FlowCharts/charts/**/*.mmd` + `*.guide.md`  
Regenerate HTML: `python3 automation/backend/build_nav_and_charts.py`  
Open index: `wfcharts` from project root (folder is `Documentation/02_FlowCharts` on disk).

## Forking

Use `wfstart` to copy and rebrand `ARCORI_*` / `Arcori_*` / `arcori` for a new product.
