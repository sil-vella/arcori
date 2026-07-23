# wfrun Dashboard GUI Implementation Plan

**Status**: Completed  
**Created**: 2026-07-11  
**Last Updated**: 2026-07-11

## Objective

Provide a browser-based alternative to the wfrun CLI numbered menu. The external `wfrun` command and CLI flow are unchanged; selecting `automation/dashboard/serve.py` launches a local dashboard with script links and an xterm.js terminal.

## Implementation Steps

- [x] Scaffold `automation/dashboard/` Python modules and static assets
- [x] Mirror wfrun script discovery with dashboard-specific exclusions
- [x] WebSocket + PTY runner with per-script env (frontend dart-defines)
- [x] HTML/JS GUI with grouped script list and xterm.js panel
- [x] Document in `wfrun.md` and `00_MASTER_PLAN.md`

## Current Progress

Implemented and smoke-tested:

- `serve.py` — aiohttp server, wfrun guard, auto-open browser
- `script_discovery.py` — 18 scripts discovered (excludes dashboard/static/helpers)
- `env_for_script.py` — frontend profile merges dart-defines file
- `pty_runner.py` — PTY spawn, resize, terminate
- Static GUI with xterm.js CDN

## Usage

```bash
python3 -m pip install -r automation/dashboard/requirements.txt
wfrun   # → local/prod → automation/dashboard/serve.py
```

## Files Modified

- `automation/dashboard/serve.py`
- `automation/dashboard/script_discovery.py`
- `automation/dashboard/env_for_script.py`
- `automation/dashboard/pty_runner.py`
- `automation/dashboard/requirements.txt`
- `automation/dashboard/static/index.html`
- `automation/dashboard/static/app.js`
- `automation/dashboard/static/style.css`
- `Documentation/00_System_Wide/wfrun.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/01_Active_Plans/wfrun-dashboard-gui.md`

## Notes

- CLI `wfrun` wrapper was not modified — GUI appears as one more script in the menu.
- Server binds localhost by default (`127.0.0.1:8765`).
- One active PTY session at a time; starting a new script stops the previous run.
