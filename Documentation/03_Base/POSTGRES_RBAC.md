# PostgreSQL RBAC — database roles and least privilege

Operator and developer reference for **role-based access control** on `Arcori_postgres`. RBAC limits what each database client can do; pair with [postgres-tls-in-transit.md](../01_Active_Plans/postgres-tls-in-transit.md) for encryption in transit and [vps-wireguard-vpn-automation.md](../01_Active_Plans/vps-wireguard-vpn-automation.md) for network access control.

## Role model

| Role | Env / URL | Used by | Privileges |
|------|-----------|---------|------------|
| `POSTGRES_USER` (owner) | `MIGRATION_DATABASE_URL` | Alembic, entrypoint migrations, `migrate.py`, notification seed | DDL, owns schema |
| `{db}_app` (default `arcori_app`) | `DATABASE_URL` | FastAPI runtime | DML on app tables; **no DDL** |
| `{db}_readonly` (default `arcori_readonly`) | `READONLY_DATABASE_URL` | Adminer, backups, reporting | `SELECT` only |

Dart does **not** connect to Postgres.

## Environment variables

| Variable | Local default | Production |
|----------|---------------|------------|
| `PG_RBAC_ENABLED` | `0` | `1` |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` | Owner bootstrap | Owner (migrations) |
| `POSTGRES_APP_USER` / `POSTGRES_APP_PASSWORD` | Same as owner when RBAC off | Distinct strong password |
| `POSTGRES_READONLY_USER` / `POSTGRES_READONLY_PASSWORD` | Dev placeholder | Distinct strong password |
| `DATABASE_URL` | App (or owner when RBAC off) | App role @ `Arcori_postgres` |
| `MIGRATION_DATABASE_URL` | Owner | Owner @ `Arcori_postgres` |
| `READONLY_DATABASE_URL` | Readonly @ host port | Readonly @ `127.0.0.1:5433` (VPN) |

See [`.env.local.sample`](../../.env.local.sample) and [`.env.prod.sample`](../../.env.prod.sample).

## Bootstrap flow (container)

On API container start ([entrypoint.sh](../../app_codebase/python_base_05/entrypoint.sh)):

1. `alembic upgrade head` using **owner** (`MIGRATION_DATABASE_URL`)
2. If `PG_RBAC_ENABLED=1`, run `python -m core.db.ensure_roles` (create roles + grants on all tables)
3. Start Gunicorn using **app** `DATABASE_URL`

## Operator commands

Apply roles manually (after `.env` loaded):

```bash
wfrun prod -- automation/production/postgres_rbac/apply_roles.sh
```

Verify least privilege:

```bash
wfrun prod -- automation/production/postgres_rbac/verify_rbac.sh
```

Manual checks:

```bash
# App — should succeed
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM platform_meta;"

# App — should fail
psql "$DATABASE_URL" -c "CREATE TABLE rbac_test (id int);"

# Readonly — should fail
psql "$READONLY_DATABASE_URL" -c "INSERT INTO platform_meta (schema_version) VALUES ('x');"
```

## Adminer (production)

Log in with **`arcori_readonly`** and `READONLY_DATABASE_URL` password — not the owner account. Server: `Arcori_postgres`, database: `arcori`.

## Enable RBAC locally

1. Set in `.env.local`: `PG_RBAC_ENABLED=1`, distinct `POSTGRES_APP_*` and `POSTGRES_READONLY_*` passwords.
2. Set `POSTGRES_APP_USER=arcori_app` (compose uses app user for `DATABASE_URL`).
3. Restart debug stack; entrypoint runs migrations then `ensure_roles`.
4. Run `verify_rbac.sh` with env loaded.

With `PG_RBAC_ENABLED=0`, `POSTGRES_APP_USER=arcori` matches owner — no separate roles required.

## Rollout on existing production DB

1. Add app/readonly passwords to `.env.prod`.
2. Deploy compose (API gets split URLs).
3. Run `apply_roles.sh` or restart API (entrypoint ensures roles after migrate).
4. Run `verify_rbac.sh`.
5. Use readonly creds in Adminer.

**Rollback:** Point compose `DATABASE_URL` back to owner until grants are fixed.

## New migrations

Tables created by Alembic (owner) receive grants via:

- `GRANT … ON ALL TABLES` on each `ensure_roles` run
- `ALTER DEFAULT PRIVILEGES FOR ROLE owner` for objects created afterward

After adding migrations, redeploy API or run `apply_roles.sh` so new tables are included in `ALL TABLES` grants.

## Related code

| Piece | Path |
|-------|------|
| URL helpers | `app_codebase/python_base_05/bin/core/db/db_config.py` |
| Role bootstrap | `app_codebase/python_base_05/bin/core/db/ensure_roles.py` |
| Apply script | `automation/production/postgres_rbac/apply_roles.sh` |
| Verify script | `automation/production/postgres_rbac/verify_rbac.sh` |
