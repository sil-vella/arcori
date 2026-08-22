# Dashboard: parallel runs of the same script

**Status**: Completed  
**Created**: 2026-08-20  
**Last Updated**: 2026-08-20

## Objective

Port the template Scripts-tab behavior: re-running a live runner opens a **new terminal tab** instead of stopping the existing PTY. Needed so `launch_android.sh` can stay up on OnePlus and DOOGEE Note 58 at the same time.

## Implementation Steps
- [x] Key server PTY sessions by uuid, not script id
- [x] On **Run script** while the active tab is running: spawn a new tab and start there
- [x] Stop / close still apply only to the active tab
- [x] Distinct log files when two runs start in the same second

## Current Progress

Ported from the template (`dashboard-parallel-script-runs.md`). Arcori `launch_android.sh` already listed both devices.

## Next Steps

None for this behavior. Restart the dashboard so `serve.py` is picked up.

## Files Modified
- `automation/dashboard/serve.py`
- `automation/dashboard/run_log.py`
- `automation/dashboard/static/app.js`
- `automation/dashboard/static/index.html`
- `automation/dashboard/static/style.css`
- `Documentation/00_System_Wide/wfrun-dashboard-gui.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/01_Active_Plans/dashboard-parallel-script-runs.md`

## Notes

- Idle / exited tabs still reuse on Run. Only a **running** tab forces a new instance.
- Stop is per-tab.

## Case study

n/a — ops PTY session keying; no Arcori game-logic change. Game narrative stays in `03_CASE_STUDY.md`.

## Task Manager

Skipped — `TM_USERNAME` / `TM_PASSWORD` empty in `.env.local`.
