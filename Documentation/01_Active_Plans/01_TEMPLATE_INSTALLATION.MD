# Template installation — new product repo

**Purpose:** End-to-end checklist after copying this FastAPI + Postgres + Dart + Flutter template into a **new product**. Covers automatic rebranding, local secrets, then production/VPS follow-ups that are not finished inside the template alone.

**Status:** Living checklist — tick items as the product matures.  
**Created:** 2026-07-20  
**Last Updated:** 2026-07-20

Related: [00_MASTER_PLAN.md](00_MASTER_PLAN.md) · [wfstart.md](../00_System_Wide/wfstart.md) · [wfsecrets.md](../00_System_Wide/wfsecrets.md) · [DRAIN_SYSTEM.md](../03_Base/DRAIN_SYSTEM.md) · [PRODUCTION_SYSTEM.md](../03_Base/PRODUCTION_SYSTEM.md)

---

## When to use this file

1. Starting a new app from this template.
2. First local bring-up after `wfstart`.
3. First staging / production VPS deploy.
4. Before treating deploys as safe to stop containers.

---

## Step 1 — Create repo and rename branding (`wfstart`)

**Done automatically** when you run the `wfstart` command (shell wrapper → `wf_start_new.py`). You do **not** hand-edit `arcori` placeholders for a greenfield install.

What `wfstart` does:

1. Copies this template into `<parent>/<project_name>/`
2. Replaces **arcori branding variants** in UTF-8 file **contents** and matching **file/directory basenames** (env prefixes, compose services, docs, `arcori*` paths, etc.)
3. Leaves `flutter_base*` / `dart_bkend_base*` / `python_base*` directory names unchanged
4. Prompts **Create git? [y/N]**; if yes, re-inits git, creates a GitHub repo, and pushes

| Template placeholder | Becomes (example `my_cool_app`) |
|----------------------|----------------------------------|
| `ARCORI` | `MY_COOL_APP` |
| `Arcori` | `MyCoolApp` |
| `arcori` | `my_cool_app` |
| `Arcori` | `My Cool App` |

Full replacement table and caveats: [wfstart.md](../00_System_Wide/wfstart.md).

After Step 1, Docker names like `Arcori_api` / `DART_SERVICE_URL` in docs below mean the **rebranded** equivalents (e.g. `MyCoolApp_api`). Base paths such as `app_codebase/flutter_base_06` stay as in the template.

- [ ] Ran `wfstart`, opened the new repo, confirmed compose service names and `*_ENV` keys match the project name.

---

## Step 2 — Local secrets and first local stack

- [ ] Copy `.env.local.sample` → `.env.local` and fill secrets (dev values OK for local).
- [ ] Copy `.env.dart.defines.local.sample` → `.env.dart.defines.local`.
- [ ] Bring up debug stack (`wfrun` → docker up, or compose with `docker-compose.debug.yml`).
- [ ] Confirm `GET http://127.0.0.1:8000/health` and Flutter launch (`automation/frontend/launch_chrome.sh`).

See [wfsecrets.md](../00_System_Wide/wfsecrets.md) and [00_MASTER_PLAN.md](00_MASTER_PLAN.md) quick start.

---

## Step 3 — Production env (product repo + VPS)

- [ ] Copy `.env.prod.sample` → `.env.prod` on the VPS; fill strong secrets (`JWT_*`, `SERVICE_KEY`, `POSTGRES_*`).
- [ ] Copy `.env.dart.defines.prod.sample` → `.env.dart.defines.prod` for release Flutter builds.
- [ ] Set `CADDY_DOMAIN` / `CADDY_GAME_DOMAIN` (or nginx equivalents) to real hostnames.
- [ ] Confirm compose injects `DART_SERVICE_URL` to the rebranded Dart service (template default: `http://Arcori_dart:8080`).
- [ ] Never commit `.env.prod` or TLS private keys.

---

## Step 4 — Edge drain (VPS / nginx repo) — with app drain

App-layer drain ships in this template ([DRAIN_SYSTEM.md](../03_Base/DRAIN_SYSTEM.md), `ops_drain.py`). **Edge drain does not** — add it in the VPS-specific nginx/automation repo.

### Host / nginx

- [ ] Flag file under app root, e.g. `/opt/apps/<product>/.draining`.
- [ ] Activate / deactivate / status script (touch/remove flag + `nginx -t` + reload).
- [ ] When flag is **active**:

| Path | Expected |
|------|----------|
| `GET /health` | Pass through → **200** |
| `/service/*` | Pass through (ops CLI + in-flight service; 401 without `X-Service-Key`) |
| `/ws`, `/authuser/*`, `/public/*`, SPA/static | **503** |

- [ ] Document `OPS_DRAIN_BASE_URL=https://<api-domain>` for operators.
- [ ] Abort on poll timeout: edge **deactivate** + `ops_drain.py exit` — **do not stop containers**.

### Combined maintenance order

```text
1. Edge --activate
2. ops_drain.py enter
3. ops_drain.py poll → ready=true
4. docker compose stop / pull / up
5. ops_drain.py exit
6. Edge --deactivate
```

### Product-repo follow-ups

- [ ] Extra in-flight service paths → `EXTRA_DRAIN_ALLOW_PREFIXES` in `drain_guard.py`.
- [ ] Product `in_flight` counters → `register_in_flight_counter`.
- [ ] Real matchmaking WS gates (same idea as template `demo/room` `subscribe`).

Active plan: [drain-maintenance-pipeline.md](drain-maintenance-pipeline.md).

---

## Step 5 — PostgreSQL TLS in transit (host certs)

Plain Docker-network Postgres is the template default. For production DB ↔ API encryption:

- [ ] Generate CA + server certs **on the VPS** under `${APP_ROOT}/data/postgres/tls/` — [Production_Host/postgres-tls-certs-on-production-host.md](../Production_Host/postgres-tls-certs-on-production-host.md).
- [ ] Align / replace `automation/production/mongodb_tls/` with Postgres TLS automation — [postgres-tls-in-transit.md](postgres-tls-in-transit.md).
- [ ] Mount certs into Postgres + API; set `PG_TLS_*` / TLS `DATABASE_URL` in prod compose.
- [ ] Keep local debug compose TLS-off.
- [ ] Cert SANs must match the **rebranded** Postgres Docker hostname.

---

## Step 6 — PostgreSQL RBAC

Template still uses a single `POSTGRES_USER` for API + migrations + Adminer.

- [ ] Split roles: owner (migrate), app (runtime DML), readonly (Adminer/backups) — [postgres-rbac-verification.md](postgres-rbac-verification.md).
- [ ] Point API `DATABASE_URL` at the app role; migrations at `MIGRATION_DATABASE_URL`.
- [ ] Run RBAC verification before treating prod as locked down.

---

## Step 7 — VPN / automation access

- [ ] WireGuard (or equivalent) so SSH, Adminer, and host Postgres are not public — [vps-wireguard-vpn-automation.md](vps-wireguard-vpn-automation.md).
- [ ] Operators run `wfrun` / `ops_drain.py` against prod only when VPN is up (if management is gated that way).

---

## Step 8 — First deploy smoke

- [ ] `curl https://<api>/health` → `db: ok` (Alembic head includes `ops_runtime`).
- [ ] With service key: `GET /service/ops/drain-status` → JSON envelope.
- [ ] Local or staging: `ops_drain.py enter` → `poll` → `exit` (app only; skip edge).
- [ ] With edge live: `/public/*` is 503 while `/health` and `/service/ops/drain-status` still reach the app.

---

## Notes

- Implementation detail stays in `03_Base/` and the linked active plans; this file is the **install / go-live order**.
- Filename was previously `01_VPS_CONFIG_ALIGNMENT.MD` — renamed to cover the full template install path, not only VPS.
