# 00_how_to — Create and Maintain `wf*` Shell Commands

This guide explains how to create new `wf*` shell commands and keep template docs aligned with the system workflow scripts.

## Canonical locations

- Workflow root: `/Users/sil/Documents/Work/00Utilities/scripts/00_workflow`
- Shell wrappers: `/Users/sil/Documents/Work/00Utilities/scripts/00_workflow/shell_commands`
- Template docs to keep aligned: `Documentation/00_System_Wide/`

## Standard pattern for a new `wf*` command

1. Add/confirm Python entrypoint in workflow root (example: `my_tool.py`).
2. Create wrapper in `shell_commands/` (example: `wfmytool`).
3. Make wrapper executable.
4. Symlink wrapper to `~/bin/wfmytool`.
5. Verify command from terminal.
6. Add/update matching doc in `Documentation/00_System_Wide/`.

## Wrapper template

Use this for wrappers that should resolve real path and run Python from workflow root:

```bash
#!/usr/bin/env bash
HERE="$(python3 -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "$0")"
ROOT="$(cd "${HERE}/.." && pwd)"
exec python3 "${ROOT}/my_tool.py" "$@"
```

### When to keep current working directory behavior

- **CWD-independent behavior**: wrapper finds Python script via real wrapper path (recommended default).
- **CWD-sensitive behavior**: Python script intentionally resolves paths from where command is run (example pattern used by `wfcharts`).

Document this explicitly in the corresponding `.md` file.

## Install and expose globally

From any terminal:

```bash
chmod +x "/Users/sil/Documents/Work/00Utilities/scripts/00_workflow/shell_commands/wfmytool"
ln -sf "/Users/sil/Documents/Work/00Utilities/scripts/00_workflow/shell_commands/wfmytool" ~/bin/wfmytool
hash -r
```

Ensure `~/bin` is on your `PATH` in `~/.zshrc`.

## Verification checklist

- `command -v wfmytool` resolves to `~/bin/wfmytool`
- `wfmytool --help` (or a safe test run) executes without path errors
- Wrapper executes correct Python entrypoint
- Symlink target path is correct

## Keep docs aligned (required)

For every `wf*` command change, update docs in `Documentation/00_System_Wide/` in the same work session.

Each command doc should include:

- Where wrapper is saved
- Python entrypoint path
- How global command is installed (symlink model)
- Current behavior summary
- CWD behavior (independent vs sensitive)
- Minimal usage examples

## Current template docs map

- [00_MASTER_PLAN.md](../01_Active_Plans/00_MASTER_PLAN.md) — documentation index + quick start
- `wfrun.md` → `shell_commands/wfrun` (Flutter / `automation/**`; backends via compose only)
- `wfstart.md` → `shell_commands/wfstart` → `wf_start_new.py`
- `wfcharts.md` → `shell_commands/wfcharts` → `open_charts_html.py` (diagrams + plain English guides)
- `wfsecrets.md` → `.env.local` / `.env.prod` / `.env.dart.defines.*`
- `Documentation/03_Base/SECURITY_SYSTEM.md` → auth tiers, JWT, fail-closed startup
- `Documentation/03_Base/ERROR_SYSTEM.md` → error catalog, HTTP/WS envelope, client policy
- `Documentation/03_Base/PRODUCTION_SYSTEM.md` → Gunicorn, Caddy, Redis, health, compose
- `Documentation/03_Base/PYTHON_DART_BACKEND.md` → FastAPI + Dart coordination, WS protocol
- `Documentation/03_Base/WS_SYSTEM.md` → WebSocket tiers and demo channels
- `Documentation/03_Base/Flutter/NAVIGATION_SYSTEM.md` → routing, drawer, `Nav`, `AppShell`
- `Documentation/03_Base/Flutter/APPBAR_WIDGET_REGISTRATION.md` → toolbar slots, `ShellAppBar`
- `Documentation/03_Base/Flutter/BOTTOM_NAV_REGISTRATION.md` → bottom action bar, `ShellBottomBar`
- `Documentation/01_Active_Plans/bottom-nav-sink.md` → implementation plan (complete)
- `Documentation/01_Active_Plans/platform-shell-boundary.md` → template scope and naming

Flowchart sources live under `Documentation/02_FlowCharts/` (capital **D**). Regenerate HTML with `python3 automation/backend/build_nav_and_charts.py`.

If a new command is added under `shell_commands/`, add its matching `.md` file here immediately.
