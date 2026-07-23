# PostgreSQL TLS in transit — server ↔ DB encryption

**Status**: Not started  
**Created**: 2026-07-11  
**Last Updated**: 2026-07-11

## Objective

Enable **TLS in transit** between application servers and PostgreSQL on production VPS. Align and replace the copied Dutch **MongoDB** TLS automation (`automation/production/mongodb_tls/`) with a **PostgreSQL** equivalent that matches this repo's stack: `Arcori_postgres`, `Arcori_api`, Docker Compose, and `DATABASE_URL` / psycopg clients.

Encryption protects credentials and query data on the Docker bridge network and any host-bound Postgres port (Adminer, operator `psql`, backup scripts).

## Context (current state)

| Area | Today |
|------|--------|
| Database | **PostgreSQL 16** (`Arcori_postgres`) — not MongoDB |
| Connection | Plain `postgresql://…@Arcori_postgres:5432/…` in compose |
| Client code | `db_config.py`, `engine.py`, `db_health.py`, Alembic, `sync_global_notifications.py` — no SSL params |
| Copied automation | `automation/production/mongodb_tls/` — Dutch paths, `mongosh`/`mongodump` flags, rop01 SSH targets |
| Local dev | `docker-compose.debug.yml` — Postgres on `127.0.0.1:5433`, TLS **off** (expected) |
| Network hardening | [vps-wireguard-vpn-automation.md](vps-wireguard-vpn-automation.md) — VPN-gate `:5432`; TLS is **defense in depth** |

## Reference (Dutch Mongo pattern to port)

| Mongo (Dutch) | PostgreSQL (this repo) |
|---------------|------------------------|
| `data/mongodb/tls/` on VPS host | `data/postgres/tls/` on VPS host |
| In-container `/etc/mongo-tls/` | In-container `/etc/postgres-tls/` |
| `mongod` requireTLS | `postgres -c ssl=on` + cert/key paths |
| `mongosh --tls --tlsCAFile=…` | `psql`/`pg_dump` via `PGSSLMODE` + `PGSSLROOTCERT` or URI `sslmode` |
| Flask `database_manager.py` TLS client | `db_config.py` + compose `DATABASE_URL` |
| `MONGO_TLS_ENABLED=auto\|0\|1` | `PG_TLS_ENABLED=auto\|0\|1` |
| `mongo_tls_common.sh` auto-detect `ca.pem` | `pg_tls_common.sh` auto-detect `ca.pem` |
| `BACKUP_LOCAL_DEV=1` skips TLS | Same — local scripts skip TLS |

---

## Target architecture

```text
VPS host
  data/postgres/tls/
    ca.pem          ← private CA (operator trust anchor)
    ca-key.pem      ← CA private key (root only, not in app containers)
    server.crt      ← Postgres server cert (+ SANs)
    server.key      ← Postgres server key

Docker network (app-network)
  Arcori_postgres :5432  ← ssl=on, mounts /etc/postgres-tls/
  Arcori_api              ← DATABASE_URL ?sslmode=verify-full&sslrootcert=/etc/postgres-tls/ca.pem
  Arcori_adminer          ← connects to postgres with SSL (Adminer env / driver)

Operator / automation (VPN)
  psql, pg_dump, migrate.py, sync_global_notifications.py
    ← PGSSLMODE / URI sslmode when PG_TLS_ENABLED
```

**Trust model (v1):** Private CA issued on VPS; server cert SANs include `Arcori_postgres`, `localhost`, `127.0.0.1`. Clients use `sslmode=verify-full` (or `verify-ca` if hostname mismatch is a problem during rollout — document choice).

**Local dev:** TLS disabled (`PG_TLS_ENABLED=0` or no `ca.pem`); unchanged plain Postgres on debug compose.

---

## Implementation steps

### Phase 0 — Replace Mongo automation with Postgres TLS package

**Action:** Rename/replace `automation/production/mongodb_tls/` → `automation/production/postgres_tls/`.

- [ ] Remove or archive Mongo-specific naming (`mongosh_tls.py`, `mongo_tls_common.sh`, Dutch container DNS names).
- [ ] Create aligned scripts (mirror Dutch layout):

| Script | Purpose |
|--------|---------|
| `generate_certs.sh` | OpenSSL CA + Postgres server cert/key |
| `fix_tls_permissions.sh` | `chmod`/`chown` for postgres UID (999) in container |
| `pg_tls_common.sh` | `pg_tls_active_on_host`, `_pg_tls_enabled`, `pg_tls_psql_env`, `pg_tls_uri_suffix` |
| `load_pg_tls_args.sh` | Bash arrays for `pg_dump`/`psql` wrappers |
| `psql_tls.py` | Python helper for in-container / script SSL env (like `mongosh_tls.py`) |
| `install_pg_tls_certs.sh` | SSH upload + run on VPS (generic env vars, not hardcoded rop01/dutch) |

- [ ] **VPS paths (template defaults):**
  - Host TLS dir: `${APP_ROOT:-/opt/apps/arcori}/data/postgres/tls`
  - Remote script stash: `/opt/backups/scripts/postgres_tls`
  - CA CN: `wf-template-pg-ca`
  - Server cert SANs: `DNS:Arcori_postgres`, `DNS:localhost`, `IP:127.0.0.1`
- [ ] **Install script env vars** (no Dutch hardcoding):
  - `VPS_SSH_HOST`, `VPS_SSH_USER`, `VPS_SSH_KEY`, `APP_ROOT`, `--dry-run`
- [ ] Delete `automation/production/mongodb_tls/` once postgres_tls is in place.

### Phase 1 — Docker Compose (production)

**Files:** `docker/docker-compose.yml`

- [ ] Mount host TLS dir read-only into Postgres:
  ```yaml
  volumes:
    - ${APP_ROOT}/data/postgres/tls:/etc/postgres-tls:ro
  ```
- [ ] Postgres `command` (or `postgresql.conf` snippet) enable SSL:
  ```text
  -c ssl=on
  -c ssl_cert_file=/etc/postgres-tls/server.crt
  -c ssl_key_file=/etc/postgres-tls/server.key
  ```
- [ ] Optionally `-c ssl_ca_file=/etc/postgres-tls/ca.pem` if client cert auth added later (not required v1).
- [ ] Mount same CA into `Arcori_api` at `/etc/postgres-tls/ca.pem` (CA only — not server key).
- [ ] Update `DATABASE_URL` for API when TLS active:
  ```text
  postgresql://user:pass@Arcori_postgres:5432/db?sslmode=verify-full&sslrootcert=/etc/postgres-tls/ca.pem
  ```
  Use compose env substitution or a small entrypoint that appends query params when `PG_TLS_ENABLED=1`.
- [ ] Healthcheck: `pg_isready` still works (non-SSL local socket inside container); verify SSL separately.
- [ ] **Do not** enable TLS in `docker-compose.debug.yml` by default.

### Phase 2 — Application & migration clients

**Files:** `app_codebase/python_base_05/bin/core/db/`

- [ ] Extend `db_config.py`:
  - Read `PG_TLS_ENABLED`, `PG_SSLMODE` (default `verify-full`), `PG_SSLROOTCERT` (default `/etc/postgres-tls/ca.pem`).
  - When TLS enabled, append SSL query params to `database_url()` / `sqlalchemy_database_url()` if not already present.
  - Helper `database_connect_kwargs()` for psycopg direct use (`db_health.py`, scripts).
- [ ] Confirm `engine.py` `create_engine()` works with SSL query string (psycopg3 parses URI params).
- [ ] Update `db_health.py` `ping_database()` / `check_database_health()` to use unified URL builder.
- [ ] Update `bin/migrate.py` and `alembic/env.py` — migrations must connect with same TLS settings as runtime.
- [ ] Add unit test: URL builder with `PG_TLS_ENABLED=0/1/auto`.

### Phase 3 — Operator & automation scripts

- [ ] `automation/backend/sync_global_notifications.py` — uses `DATABASE_URL` from `wfrun`; document prod URL must include SSL or rely on `db_config`-style env augmentation when run against VPS through VPN tunnel.
- [ ] `load_pg_tls_args.sh` — export for shell wrappers:
  ```bash
  PGSSLMODE=verify-full
  PGSSLROOTCERT=/path/to/ca.pem
  ```
- [ ] `psql_tls.py` — `psql_tls_env()` for Python playbooks / future backup scripts.
- [ ] Document `pg_dump` / `pg_restore` one-liners with TLS for backups (future backup repo can source `pg_tls_common.sh`).
- [ ] Adminer: set driver SSL options or use `ADMINER_DEFAULT_SERVER` with SSL-capable DSN if needed; verify login via VPN after deploy.

### Phase 4 — Environment & secrets

**Files:** `.env.prod.sample`, [wfsecrets.md](../00_System_Wide/wfsecrets.md)

- [ ] Add:
  ```bash
  PG_TLS_ENABLED=auto          # auto | 0 | 1
  PG_SSLMODE=verify-full       # require | verify-ca | verify-full
  PG_SSLROOTCERT=/etc/postgres-tls/ca.pem
  APP_ROOT=/opt/apps/arcori
  ```
- [ ] Local `.env.local.sample`: `PG_TLS_ENABLED=0` (explicit off).
- [ ] Note: `DATABASE_URL` for host-side tools (VPN `127.0.0.1:5433`) needs host path to `ca.pem` when connecting through published port.

### Phase 5 — VPS rollout procedure

- [ ] Run `install_pg_tls_certs.sh` on target VPS (greenfield or rotation with `--force`).
- [ ] Run `fix_tls_permissions.sh` on host TLS dir.
- [ ] Redeploy compose: `docker compose --env-file ../.env.prod -f docker-compose.yml up -d`.
- [ ] Verify:
  - `curl https://<api>/health` → `db: ok`
  - From API container: `psql "$DATABASE_URL" -c 'SELECT 1'`
  - From host (VPN): `psql` with TLS to `127.0.0.1:5433`
  - Plain connection without SSL fails when Postgres configured to reject non-SSL (optional hardening: `hostssl` only in `pg_hba.conf` — phase 5b).
- [ ] **Cert rotation:** `--force` regenerate → redeploy postgres + api → update any external clients with new CA.

### Phase 5b — Optional hardening (pg_hba)

- [ ] Custom `pg_hba.conf` or init script: require `hostssl` for TCP connections from `app-network` subnet.
- [ ] Keep local socket (`local all all trust`) for in-container health if needed.
- [ ] Test rollback path before enforcing reject-non-SSL.

### Phase 6 — Documentation

- [ ] Add `Documentation/03_Base/POSTGRES_TLS.md` — operator runbook (generate, install, verify, rotate, local vs prod).
- [ ] Update [PRODUCTION_SYSTEM.md](../03_Base/PRODUCTION_SYSTEM.md) — PostgreSQL TLS section.
- [ ] Update [SECURITY_SYSTEM.md](../03_Base/SECURITY_SYSTEM.md) — `DATABASE_URL`, TLS env vars, threat model row for DB traffic.
- [ ] Cross-link [vps-wireguard-vpn-automation.md](vps-wireguard-vpn-automation.md) (VPN + TLS layers).
- [ ] Mark this plan **Completed** when all phases done.

---

## `generate_certs.sh` outline (Postgres)

Same OpenSSL flow as Dutch Mongo script, different outputs:

```text
ca.pem, ca-key.pem          ← CA
server.key                  ← Postgres private key
server.crt                  ← Server cert (cert only, or fullchain)
```

SANs: `Arcori_postgres`, `localhost`, `127.0.0.1`.  
Permissions: `server.key` `600`, certs `644`, dir `755`, owner readable by postgres container user.

---

## Verification checklist

| Check | Expected |
|-------|----------|
| API `/health` | `db: ok` with TLS enabled |
| `PG_TLS_ENABLED=0` local debug compose | Stack starts, no cert mount required |
| Prod without `ca.pem` + `PG_TLS_ENABLED=auto` | Plain connection (backward compatible until certs installed) |
| Prod with `ca.pem` + `auto` | SSL required on client connections |
| `sync_global_notifications.py` (prod) | Connects over VPN + TLS |
| Wireshark / tcpdump on bridge (optional) | Postgres traffic encrypted after enable |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Hostname mismatch (`verify-full` fails) | SAN includes Docker service name; fall back to `verify-ca` temporarily |
| Cert permissions block postgres start | `fix_tls_permissions.sh`; document UID 999 |
| Mixed TLS/plain during rollout | `PG_TLS_ENABLED=auto`; staged deploy: certs first, then client URL, then pg_hba hardening |
| Local dev broken by auto TLS | `BACKUP_LOCAL_DEV=1` / `PG_TLS_ENABLED=0` in `.env.local` |
| Mongo scripts confuse operators | Remove `mongodb_tls/` after postgres_tls lands |

---

## Current progress

- `automation/production/mongodb_tls/` copied from Dutch repo — **not aligned** with PostgreSQL or WF template paths.
- No compose SSL config, no client SSL params, no Postgres cert generation.

## Next steps

1. Implement `automation/production/postgres_tls/` (Phase 0).
2. Wire production compose + `db_config.py` (Phases 1–2).
3. Run cert install on VPS and verify health (Phase 5).

## Files to create / modify

| File | Action |
|------|--------|
| `automation/production/postgres_tls/*` | Create (replace mongodb_tls) |
| `automation/production/mongodb_tls/` | Delete after migration |
| `docker/docker-compose.yml` | Postgres SSL + API CA mount + DATABASE_URL |
| `app_codebase/python_base_05/bin/core/db/db_config.py` | TLS URL builder |
| `app_codebase/python_base_05/bin/core/db/db_health.py` | Use unified config |
| `app_codebase/python_base_05/bin/migrate.py` | TLS-aware connection |
| `app_codebase/python_base_05/alembic/env.py` | TLS-aware connection |
| `.env.prod.sample`, `.env.local.sample` | PG_TLS_* vars |
| `Documentation/03_Base/POSTGRES_TLS.md` | Operator runbook |
| `Documentation/03_Base/PRODUCTION_SYSTEM.md` | Cross-link |
| `Documentation/03_Base/SECURITY_SYSTEM.md` | Cross-link |

## Notes

- Dutch stack used MongoDB + Flask; this template uses **PostgreSQL + FastAPI** — do not reuse `mongosh`/`mongodump` helpers; use `psql`/`pg_dump` / psycopg URI params.
- Dart backend does **not** connect to Postgres directly today — only FastAPI and operator tools need TLS client config.
- Redis presence cache is separate; not in scope unless Redis TLS is added later.
- Prefer **one private CA per VPS/app root**; do not commit `ca-key.pem` or server keys to git.
