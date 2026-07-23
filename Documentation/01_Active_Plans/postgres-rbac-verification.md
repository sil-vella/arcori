# PostgreSQL RBAC — verify and enforce database user roles

**Status**: Completed  
**Created**: 2026-07-11  
**Last Updated**: 2026-07-20

## Objective

Audit, implement, and **verify** least-privilege **RBAC** for PostgreSQL on production and local compose. Separate owner / app / readonly roles, split connection URLs, and automated verification.

**Reference doc:** [POSTGRES_RBAC.md](../03_Base/POSTGRES_RBAC.md)

---

## Implementation summary

| Phase | Status |
|-------|--------|
| Env samples + compose URL split | Done |
| `ensure_roles.py` + `apply_roles.sh` | Done |
| Entrypoint: migrate (owner) → ensure_roles → runtime (app) | Done |
| `db_config`, Alembic, `migrate.py`, seed script | Done |
| `verify_rbac.sh` | Done |
| Tests + docs | Done |

---

## Target role model (implemented)

| Role | URL | Client |
|------|-----|--------|
| `POSTGRES_USER` (owner) | `MIGRATION_DATABASE_URL` | Alembic, entrypoint, `migrate.py`, notification seed |
| `arcori_app` | `DATABASE_URL` | FastAPI runtime |
| `arcori_readonly` | `READONLY_DATABASE_URL` | Adminer, backups |

Local default: `PG_RBAC_ENABLED=0` with `POSTGRES_APP_USER=arcori` (same as owner).  
Production sample: `PG_RBAC_ENABLED=1` with distinct passwords.

---

## Verification

```bash
wfrun prod -- automation/production/postgres_rbac/verify_rbac.sh
```

Pytest: `tests/core/db/test_db_config.py` (always); `test_rbac_app_role.py` (when `PG_RBAC_ENABLED=1`).

---

## Files created / modified

| File | Action |
|------|--------|
| `app_codebase/python_base_05/bin/core/db/db_config.py` | Migration/readonly URL helpers, `pg_rbac_enabled()` |
| `app_codebase/python_base_05/bin/core/db/ensure_roles.py` | Idempotent role + grant bootstrap |
| `app_codebase/python_base_05/alembic/env.py` | Migration URL |
| `app_codebase/python_base_05/bin/migrate.py` | Migration URL |
| `app_codebase/python_base_05/entrypoint.sh`, `entrypoint.dev.sh` | Migrate → ensure_roles |
| `automation/production/postgres_rbac/apply_roles.sh` | Operator apply |
| `automation/production/postgres_rbac/verify_rbac.sh` | Operator verify |
| `automation/backend/sync_global_notifications.py` | Prefers `MIGRATION_DATABASE_URL` |
| `docker/docker-compose.yml`, `docker-compose.debug.yml` | Split URLs |
| `.env.local.sample`, `.env.prod.sample` | RBAC env vars |
| `tests/core/db/test_db_config.py`, `test_rbac_app_role.py` | Tests |
| `Documentation/03_Base/POSTGRES_RBAC.md` | Operator runbook |
| `Documentation/03_Base/SECURITY_SYSTEM.md`, `PRODUCTION_SYSTEM.md`, `wfsecrets.md` | Cross-links |

---

## Notes

- RBAC is independent of [postgres-tls-in-transit.md](postgres-tls-in-transit.md).
- Run `apply_roles.sh` or redeploy API after new Alembic migrations so new tables receive grants.
- Adminer on prod: use readonly credentials only.
