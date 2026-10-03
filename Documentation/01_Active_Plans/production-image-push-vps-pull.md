# Production image push and VPS pull

**Status:** In Progress  
**Created:** 2026-09-24  
**Last Updated:** 2026-09-24

## Objective

Replicate Dutch playbooks 06/07/08 as wfrun/dashboard runners: build and push FastAPI + Dart images to Docker Hub, then SSH to the VPS to pull and run a pull-only compose stack. Always use **prod** env via wfrun.

## Steps / Tasks

- [x] Shared helper `automation/backend/image_tag_env.py` (tag, upsert, LOGGING_SWITCH flip/restore, prod gate)
- [x] `automation/backend/build_and_push_api_docker.py`
- [x] `automation/backend/build_and_push_dart_docker.py`
- [x] `automation/production/docker-compose.vps.yml` + `Caddyfile.prod`
- [x] `automation/production/deploy_vps.py` (SSH, copy, pull, up, health, prune)
- [x] Exclude helpers from wfrun menu; document in `wfrun.md`; sample keys in `.env.prod.sample`

## Current Progress

Implementation complete in-repo. Operator still fills real `VPS_*` / Hub login in `.env.prod` before first release run.

## Next Steps

1. Set `VPS_SSH_*`, `CADDY_DOMAIN`, secrets in `.env.prod`
2. `docker login` as Hub user
3. Run the three wfrun **prod** scripts in order on a real VPS with Docker already installed

## Files Modified

- `automation/backend/image_tag_env.py` (new)
- `automation/backend/build_and_push_api_docker.py` (new)
- `automation/backend/build_and_push_dart_docker.py` (new)
- `automation/production/docker-compose.vps.yml` (new)
- `automation/production/Caddyfile.prod` (new)
- `automation/production/deploy_vps.py` (new)
- `automation/wfrun_excluded_scripts.txt`
- `.env.prod.sample`
- `Documentation/00_System_Wide/wfrun.md`
- `Documentation/01_Active_Plans/00_MASTER_PLAN.md`
- `Documentation/01_Active_Plans/production-image-push-vps-pull.md` (this file)

## Notes

- Local `docker_up.sh` / `docker_up_build.sh` and laptop compose files keep `build:` — VPS uses a separate pull-only compose.
- VPS edge is **nginx on api.arcori.app** (dedicated vhost; marketing stays on arcori.app). Dart WS public path: `/game/ws/`.
- Nginx rewrite prompt: **5s timeout / non-interactive → skip** (type `y` to rewrite).
- Task Manager: Ops workstream card (not App Dev).
