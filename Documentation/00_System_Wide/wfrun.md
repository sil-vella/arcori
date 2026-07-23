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
wfrun   # → automation/backend/docker_up_build.sh
```

That runs `docker compose --env-file <env> -f <compose> up --build -d` with:

| `WFRUN_MODE` | Compose file | Env file |
|--------------|--------------|----------|
| `local` | `docker/docker-compose.debug.yml` | `.env.local` |
| `prod` | `docker/docker-compose.yml` | `.env.prod` |

Rebuild a single service (pass args after selecting the script, or run directly with wfrun env exported):

```bash
# e.g. API only after requirements.txt changed
bash automation/backend/docker_up_build.sh Arcori_api
```

Sync global notification campaigns from git JSON into Postgres (loads `DATABASE_URL` from `.env.local` / `.env.prod`):

```bash
wfrun   # → automation/backend/sync_global_notifications.py
# optional: --prune to deactivate campaigns not in the seed file
```

Manual equivalent (local):

```bash
cd docker
docker compose --env-file ../.env.local -f docker-compose.debug.yml up --build -d
```

Services: Postgres `:5433`, FastAPI `:8000`, Dart `:8080`, Adminer `:8081`. All load `../.env.local` via `env_file`. See [`wfsecrets.md`](wfsecrets.md).

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
