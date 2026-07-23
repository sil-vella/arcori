# wfstart — Workflow Starter Command

## Where the shell command is saved

- Wrapper script: `/Users/sil/Documents/Work/00Utilities/scripts/00_workflow/shell_commands/wfstart`
- Python entrypoint: `/Users/sil/Documents/Work/00Utilities/scripts/00_workflow/wf_start_new.py`
- Typical global command setup: symlink wrapper to `~/bin/wfstart` (or another directory on `PATH`)

## What it does (current behavior)

`wfstart` is a thin shell wrapper that:

1. Resolves its own real path (so symlinked invocation works)
2. Computes workflow root (`.../scripts/00_workflow`)
3. Executes `python3 <root>/wf_start_new.py "$@"`

It does not change your shell CWD before launching Python.

### Full workflow (`wf_start_new.py`)

After you pick a parent folder and enter a **project name**, `wfstart`:

1. Lists `app_dev*` templates under `/Users/sil/Documents/Work/00Utilities/templates`
2. Copies the selected template into `<parent>/<project_name>/` (full source tree; excludes `*.code-workspace`, template `.git`, `build/`, `.dart_tool/`, caches)
   - If the destination already exists: prompt **replace** / **use existing** / **abort** (never silently skip a partial tree)
   - Verifies top-level dirs (`Documentation`, `app_codebase`, `automation`, `docker`, `assets`) after copy; failed/partial copies are removed
3. **Replaces arcori branding variants** in UTF-8 file **contents** and matching **file/directory basenames** (see table below); leaves `flutter_base*` / `dart_bkend_base*` / `python_base*` names alone
4. Prompts **Create git? [y/N]** — if yes: re-inits local git, commits, creates a GitHub repo with `gh`, and pushes
   - If that GitHub **name already exists**, prompts for a **different GitHub repo name** (local folder unchanged) or **`skip`** (keeps local git, no remote/push)
   - If no: leaves the copy without running git/GitHub steps

Helper function names such as `wf_env()` / `wfEnv()` are **not** renamed — only placeholder **strings** in config, compose, and docs.

`flutter_base*` / `dart_bkend_base*` / `python_base*` directory names are **left unchanged**.

Generated / VCS trees are skipped: `.git`, `build`, `.dart_tool`, `__pycache__`, `node_modules`, `.idea`, `.venv`, `venv`, `.pytest_cache`.

---

## Branding replacement (`arcori` → your project)

Given project name **`my_cool_app`** (spaces become underscores), `replace_arcori_in_files()` applies these replacements **in order** (longest / most specific first) to **file contents and path basenames**:

| Template placeholder | Case / pattern | Replaced with | Example in repo |
|----------------------|----------------|---------------|-----------------|
| `ARCORI` | SCREAMING_SNAKE env prefix | `MY_COOL_APP` | `ARCORI_ENV` → `MY_COOL_APP_ENV` |
| `Arcori:` | PascalCase + colon (Redis key prefix value) | `MyCoolApp:` | `Arcori:cache:` → `MyCoolApp:cache:` |
| `Arcori` | PascalCase (+ `_` suffix preserved) | `MyCoolApp` | `Arcori_api` → `MyCoolApp_api` |
| `Arcori` | Title words (display / docs) | `My Cool App` | `# Arcori — Production` → `# My Cool App — Production` |
| `arcori` | snake_case slug | `my_cool_app` | compose `name:`, `POSTGRES_USER`, `silvella/arcori_api`; also dirs/files like `arcori.iml`, `…/arcori/` |
| `arcori` | flat lowercase | `mycoolapp` | rare concatenated form |

### Derived forms (from project name input)

| Form | Rule | `my_cool_app` example |
|------|------|------------------------|
| **env_prefix** | snake → UPPER | `MY_COOL_APP` |
| **snake** | segments lowercased, `_` joined | `my_cool_app` |
| **pascal** | each segment Title-cased, concatenated | `MyCoolApp` |
| **title** | each segment capitalized, space-separated | `My Cool App` |
| **flat** | segments lowercased, no separators | `mycoolapp` |

Single-word names work too: `myapp` → env `MYAPP`, pascal `Myapp`, title `Myapp`.

### What gets updated in this template

| Area | Placeholders touched |
|------|----------------------|
| `.env.local.sample` / `.env.prod.sample` | `ARCORI_*`, `arcori`, `Arcori:cache:` |
| `docker/docker-compose*.yml` | `Arcori_*`, `arcori`, image tags |
| `docker/caddy/Caddyfile` | `Arcori_api` hostname |
| Python config | `ARCORI_*` env reads, error messages |
| Docs / flowcharts | `Arcori`, `Arcori_*`, `ARCORI_*` |
| Demo strings | `"Arcori cached demo"` → `"My Cool App cached demo"` |
| On-disk paths | e.g. `arcori.iml`, `kotlin/…/arcori/`, `modules/arcori_product/` |

### What is intentionally unchanged

| Item | Why |
|------|-----|
| `wf_env()`, `wfEnv()` | Helper names stay; only env **key strings** change |
| Binary files | Contents skipped (non–UTF-8); path basenames still renamed when they match |
| `flutter_base*` / `dart_bkend_base*` / `python_base*` | Platform tree directory names stay; only `arcori` branding inside them is rewritten |

### Flutter URL env (this template)

After branding, env keys in [`.env.dart.defines.local.sample`](../../.env.dart.defines.local.sample) become the product prefix (e.g. `MY_COOL_APP_API_WS_URL`). Paths still point at `app_codebase/flutter_base_06` until you change them by hand.

| Variable (template form) | Example (local) | Used by |
|----------|-----------------|---------|
| `ARCORI_API_WS_URL` | `ws://127.0.0.1:8000/ws/authuser` | Flutter `String.fromEnvironment` in [`ws_config.dart`](../../app_codebase/flutter_base_06/lib/core/ws/ws_config.dart) |
| `ARCORI_DART_WS_URL` | `ws://127.0.0.1:8080/ws/authuser` | same |
| `ARCORI_API_REST_URL` | `http://127.0.0.1:8000` | REST dev-login for WS demo |

**This template** includes `python_base_05` (FastAPI + WS), `dart_bkend_base_02`, and `flutter_base_06`. Branding replacements apply inside all three trees; the directory names themselves remain.

---

## Usage

```bash
wfstart
wfstart arg1 arg2
```

Interactive prompts:

1. Browse folders under `/Users/sil/Documents/work`
2. Enter project name (creates directory if missing)
3. Select an `app_dev*` template to copy

Any command-line args are passed directly to `wf_start_new.py`.

### Rename only (wfrun)

Standalone runner (does **not** use `wfstart`): replace **arcori branding variants only** in the current repo via `wfrun`. Leaves `flutter_base*` / `dart_bkend_base*` / `python_base*` directory names alone.

```bash
wfrun   # → automation/local/rename_arcori_branding.py
```

Optional project name arg after selection:

```bash
# after wfrun selects the script:
my_cool_app
```

Requires `WFRUN_ROOT` + `WFRUN_MODE` (set by `wfrun`). `wfrun` only lists scripts under `automation/<subdir>/` (not directly in `automation/`).

---

## Notes

- Main workflow logic lives in `wf_start_new.py`, not in the shell wrapper
- Branding logic: `apply_template_branding_renames()` → `replace_arcori_in_files()` / `rename_tree_entries()` (arcori variants only; base tree dirs unchanged)
- Same branding-only behavior via wfrun: [`automation/local/rename_arcori_branding.py`](../../automation/local/rename_arcori_branding.py)
- See also: [platform-shell-boundary.md](../01_Active_Plans/platform-shell-boundary.md) (naming convention source for this template)
