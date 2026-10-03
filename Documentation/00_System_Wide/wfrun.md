# wfrun — Environment + Automation Runner

## Where the shell command is saved

- Wrapper script: `/Users/sil/Documents/Work/00Utilities/scripts/00_workflow/shell_commands/wfrun`
- Typical global command setup: symlink wrapper to `~/bin/wfrun` (or another directory on `PATH`)

## What it does (current behavior)

`wfrun` is the interactive runner for project-local automation scripts.

From your current directory, it walks upward until it finds a folder containing `automation/`. That folder becomes `ROOT`.

Then it:

1. Prompts for environment (`local` or `prod`, default `local`)
2. Shows a numbered menu of runnable files under `ROOT/automation` (minimum depth 2)
3. Loads env file(s) **after** script selection, based on profile:
   - **All scripts:** `ROOT/.env.local` or `ROOT/.env.prod`
   - **`automation/frontend/*` only:** also `ROOT/.env.dart.defines.local` or `ROOT/.env.dart.defines.prod`
4. Exports `WFRUN_*` metadata and runs the selected script (child inherits the full environment)

## Usage

```bash
wfrun
```

## Required project structure

```text
project/
├── .env.local
├── .env.prod
├── .env.dart.defines.local      # Flutter dart-define SSOT (local)
├── .env.dart.defines.prod       # Flutter dart-define SSOT (prod)
├── .env.dart.defines.local.sample
├── .env.dart.defines.prod.sample
└── automation/
    ├── frontend/
    ├── backend/
    └── ...
```

Copy samples: [`.env.local.sample`](../../.env.local.sample), [`.env.dart.defines.local.sample`](../../.env.dart.defines.local.sample), etc.

## Script execution rules

- `*.sh` -> `bash <script>`
- `*.py` -> `python3 <script>`
- `*.yml`, `*.yaml` -> `ansible-playbook <script>`
- other files -> executed directly only if executable

If the selected file is neither supported extension nor executable, `wfrun` exits with an error.

## Menu filtering

The menu lists only runnable scripts: `*.sh`, `*.py`, `*.yml`, `*.yaml`, or executable files. Other extensions (`.txt`, `.json`, `.html`, `.css`, `.js`, …) are omitted.

Additional exclusions live in [`automation/wfrun_excluded_scripts.txt`](../../automation/wfrun_excluded_scripts.txt) — one path per line, relative to `automation/` (comments with `#` allowed). Example: `dashboard/env_for_script.py` hides that helper while `dashboard/serve.py` remains listed.

## Environment profiles

| Script path | `local` loads | `prod` loads | `WFRUN_PROFILE` |
|-------------|---------------|--------------|-----------------|
| `automation/frontend/*` | `.env.local` + `.env.dart.defines.local` | `.env.prod` + `.env.dart.defines.prod` | `frontend` |
| anything else | `.env.local` | `.env.prod` | `backend` |

Missing any required env file stops execution before the script runs.

## Exported metadata (child scripts)

| Variable | Meaning |
|----------|---------|
| `WFRUN_MODE` | `local` or `prod` |
| `WFRUN_PROFILE` | `frontend` or `backend` |
| `WFRUN_ROOT` | Project root (contains `automation/`) |
| `WFRUN_CALLER_DIR` | Directory you were in when you invoked `wfrun` |
| `WFRUN_ENV_FILE` | Path to base env file that was loaded |
| `WFRUN_DART_DEFINES_FILE` | Path to dart-defines file (frontend profile; loaded into env) |

**Launch/build scripts must not re-source env files** when launched via `wfrun` (they inherit exported vars). See [`launch_chrome.sh`](../../automation/frontend/launch_chrome.sh).

Verify with:

```bash
wfrun   # → automation/frontend/print_wfrun_env.sh or launch_chrome.sh
```

## Backend local runs (FastAPI + Dart WS)

**Docker Compose only** — use wfrun so `.env.local` / `.env.prod` are loaded automatically:

```bash
wfrun   # → automation/backend/docker_up.sh        # start only (no rebuild)
wfrun   # → automation/backend/docker_up_build.sh  # rebuild + start
```

Both use the same env/compose mapping; only `--build` differs:

| Script | Compose command |
|--------|-----------------|
| `docker_up.sh` | `up -d`, or **`restart`** if the engine and target containers are already running |
| `docker_up_build.sh` | `up --build -d` |

| `WFRUN_MODE` | Compose file | Env file |
|--------------|--------------|----------|
| `local` | `docker/docker-compose.debug.yml` | `.env.local` |
| `prod` | `docker/docker-compose.yml` | `.env.prod` |

**Docker:** start Docker Desktop yourself first. `docker_up.sh` / `docker_up_build.sh` exit with a message if the daemon is down; otherwise `up -d` or **`restart`** when the stack is already running.

**Optional `global.log` mirror:** set `WFRUN_MIRROR_GLOBAL_LOG=1` in the environment (or check **Mirror [dev] → global.log** on the dashboard when running these scripts). After compose succeeds, the up script spawns `docker_logs_to_global_log.sh` in a detached session (skips if already running). Detached mirror stdout goes to `.dashboard_logs/docker_logs_mirror.log`.

Rebuild or start a single service (pass args after selecting the script, or run directly with wfrun env exported):

```bash
# e.g. API only after requirements.txt changed
bash automation/backend/docker_up_build.sh Arcori_api
# start existing images only
bash automation/backend/docker_up.sh Arcori_api
```

Sync global notification campaigns from git JSON into Postgres (loads `DATABASE_URL` from `.env.local` / `.env.prod`):

```bash
wfrun   # → automation/backend/sync_global_notifications.py
# optional: --prune to deactivate campaigns not in the seed file
```

Manual equivalent (local):

```bash
cd docker
docker compose --env-file ../.env.local -f docker-compose.debug.yml up -d          # no rebuild
docker compose --env-file ../.env.local -f docker-compose.debug.yml up --build -d  # rebuild
```

Services: Postgres `:5433`, FastAPI `:8000`, Dart `:8080`, Adminer `:8081`. All load `../.env.local` via `env_file`. See [`wfsecrets.md`](wfsecrets.md).

## Production image push + VPS pull

Hub publish and remote deploy runners **require `WFRUN_MODE=prod`** (choose **prod** in wfrun/dashboard so `.env.prod` is loaded). Selecting **local** exits immediately.

| Order | Script | Role |
|-------|--------|------|
| 1 | `automation/backend/build_and_push_api_docker.py` | Build `silvella/arcori_api`, push Hub, upsert `API_IMAGE_TAG` |
| 2 | `automation/backend/build_and_push_dart_docker.py` | Build `silvella/arcori_dart` (`--target prod`), push Hub, upsert `DART_IMAGE_TAG` |
| 3 | `automation/production/deploy_vps.py` | SSH: copy `.env` + pull-only compose + catalogs → `pull` + `up -d` + nginx **api.arcori.app** vhost |
| — | `automation/production/sync_ai_players_vps.py` | Replace **AI players only** on VPS DB + their Kin Lottie/design files (from local feed) |

```bash
wfrun   # mode: prod → automation/backend/build_and_push_api_docker.py
wfrun   # mode: prod → automation/backend/build_and_push_dart_docker.py
wfrun   # mode: prod → automation/production/deploy_vps.py
wfrun   # mode: prod → automation/production/sync_ai_players_vps.py
```

- Tag default: `{APP_VERSION}-{git short sha}` (override with `IMAGE_TAG`). Platform default: `linux/amd64` (`DOCKER_PLATFORM`).
- Before each image build, `LOGGING_SWITCH` is forced off under that build context and restored afterward.
- Deploy needs `VPS_SSH_HOST`, `VPS_SSH_USER`, `VPS_SSH_KEY`, `API_IMAGE_TAG`, `DART_IMAGE_TAG` in `.env.prod`. `APP_ROOT` defaults to `/opt/apps/arcori`.
- **AI sync:** after local `feed_ai_players`, run prod `sync_ai_players_vps.py`. Deletes/replaces only users with `*@arcoriaiplayer.app` or `avari_profiles.notes=ai_seed:v1`, plus their Kin media under `data/uploads/kin/{players,designs}`. Source DB: `AI_SYNC_SOURCE_DATABASE_URL` or `.env.local` `MIGRATION_DATABASE_URL`. Use `--dry-run` to validate export without VPS writes.
- **VPS edge:** host **nginx** on `api.arcori.app` (dedicated vhost). Compose publishes API `127.0.0.1:8000` and Dart `127.0.0.1:8085` only — **no Caddy on 80/443**. Site template: [`nginx-api.arcori.app.conf`](../../automation/production/nginx-api.arcori.app.conf). Marketing `arcori.app` stays PHP-only (deploy strips any leftover backend snippet).
- Flutter prod URLs: `https://api.arcori.app`, `wss://api.arcori.app/ws/authuser`, `wss://api.arcori.app/game/ws/authuser` (see `.env.dart.defines.prod.sample`).
- **Prerequisite on VPS:** Docker Engine + Compose plugin; SSH user can run docker; DNS `api.arcori.app` → VPS (Certbot runs on first deploy if cert missing). Does not install Docker or touch Dutch/other vhosts.

See [`.env.prod.sample`](../../.env.prod.sample) for placeholder keys.

## Flutter env injection (`dart-define`)

Flutter URLs, web port, and other client keys live in **`.env.dart.defines.local`** / **`.env.dart.defines.prod`** (not in `.env.local`).

[`launch_chrome.sh`](../../automation/frontend/launch_chrome.sh):

1. Requires `WFRUN_MODE` + `WFRUN_PROFILE=frontend`
2. Requires `ARCORI_API_*`, `FLUTTER_WEB_PORT`, `FLUTTER_WEB_HOSTNAME` in the exported env
3. Builds `--dart-define=KEY=value` from keys in `WFRUN_DART_DEFINES_FILE`, values from the shell env ([`build_dart_defines_from_wfrun_env`](../../automation/frontend/dart_defines_from_env.sh))
4. Runs `flutter run -d chrome`

Dart reads compile-time values via `String.fromEnvironment` in [`ws_config.dart`](../../app_codebase/flutter_base_06/lib/core/ws/ws_config.dart) — no hardcoded URL defaults in app code.

## Dashboard GUI (alternative to the CLI menu)

The numbered **CLI menu remains the default** — use it anytime with plain `wfrun`. The dashboard is an optional browser UI for the same scripts.

```bash
# One-time dependency (outside Docker / API venv)
python3 -m pip install -r automation/dashboard/requirements.txt

# Same wfrun flow: pick local/prod, then select the dashboard script
wfrun   # → automation/dashboard/serve.py
```

Opens `http://127.0.0.1:8765/` (override with `WFRUN_DASHBOARD_PORT` / `WFRUN_DASHBOARD_HOST`). Click a script to run it in an embedded xterm.js terminal. Env is loaded once by wfrun (`local` / `prod`); child scripts get the same per-profile env rules as the CLI (including dart-defines for `automation/frontend/*`).

See [`wfrun-dashboard-gui.md`](../01_Active_Plans/wfrun-dashboard-gui.md).

## Notes

- `wfrun` does not depend on where the wrapper itself is located once invoked from `PATH`
- Root detection is based on finding `automation/` in current directory ancestry
- **Backends (FastAPI + Dart)** run via Docker Compose only — [`docker-compose.debug.yml`](../../docker/docker-compose.debug.yml)
- `wfrun` is for **Flutter** and other `automation/**` scripts, not for starting API/Dart servers

## Related

- [`wfsecrets.md`](wfsecrets.md) — backend secrets in `.env.local` / `.env.prod`
- [`expenvs.sh`](../../expenvs.sh) — older project-local menu (does not load dart-defines profile)
