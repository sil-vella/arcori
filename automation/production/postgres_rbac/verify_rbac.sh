#!/usr/bin/env bash
# dash Verify Postgres RBAC least-privilege roles
set -euo pipefail

failures=0

log_ok() { echo "[ok] $*"; }
log_fail() { echo "[FAIL] $*" >&2; failures=$((failures + 1)); }

if [[ "${PG_RBAC_ENABLED:-0}" != "1" ]]; then
  echo "PG_RBAC_ENABLED is not 1 — skipping verify_rbac (single-user mode)."
  exit 0
fi

APP_URL="${DATABASE_URL:-}"
MIGRATION_URL="${MIGRATION_DATABASE_URL:-}"
READONLY_URL="${READONLY_DATABASE_URL:-}"

if [[ -z "${APP_URL}" || -z "${MIGRATION_URL}" || -z "${READONLY_URL}" ]]; then
  echo "ERROR: DATABASE_URL, MIGRATION_DATABASE_URL, and READONLY_DATABASE_URL required" >&2
  exit 1
fi

APP_USER="${POSTGRES_APP_USER:-}"
READONLY_USER="${POSTGRES_READONLY_USER:-}"

psql_app() { psql "${APP_URL}" -v ON_ERROR_STOP=1 -Atqc "$1"; }
psql_ro() { psql "${READONLY_URL}" -v ON_ERROR_STOP=1 -Atqc "$1"; }
psql_owner() { psql "${MIGRATION_URL}" -v ON_ERROR_STOP=1 -Atqc "$1"; }

run_expect_fail() {
  local label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    log_fail "${label} (expected failure)"
  else
    log_ok "${label} denied as expected"
  fi
}

# 1 — app role not superuser
if [[ -n "${APP_USER}" ]]; then
  super=$(psql_owner "SELECT rolsuper FROM pg_roles WHERE rolname = '${APP_USER}'" 2>/dev/null || echo "t")
  if [[ "${super}" == "f" ]]; then
    log_ok "app role is not superuser"
  else
    log_fail "app role rolsuper=${super}"
  fi
fi

# 2 — app cannot DDL
run_expect_fail "app CREATE TABLE" psql_app "CREATE TABLE rbac_probe_verify (id int)"

# 3 — app cannot DROP
run_expect_fail "app DROP TABLE users" psql_app "DROP TABLE users"

# 4 — app can SELECT
if psql_app "SELECT 1 FROM platform_meta LIMIT 1" >/dev/null 2>&1; then
  log_ok "app SELECT on platform_meta"
else
  log_fail "app SELECT on platform_meta"
fi

# 5 — app cannot write alembic_version
if psql_app "SELECT 1 FROM information_schema.tables WHERE table_name = 'alembic_version'" | grep -q 1; then
  run_expect_fail "app UPDATE alembic_version" psql_app "UPDATE alembic_version SET version_num = version_num"
fi

# 6 — readonly cannot INSERT
run_expect_fail "readonly INSERT" psql_ro "INSERT INTO platform_meta (schema_version) VALUES ('rbac-test')"

# 7 — readonly can SELECT
if psql_ro "SELECT 1 FROM platform_meta LIMIT 1" >/dev/null 2>&1; then
  log_ok "readonly SELECT on platform_meta"
else
  log_fail "readonly SELECT on platform_meta"
fi

# 8 — owner can read alembic_version
if psql_owner "SELECT version_num FROM alembic_version LIMIT 1" >/dev/null 2>&1; then
  log_ok "owner SELECT alembic_version"
else
  log_fail "owner SELECT alembic_version"
fi

# 9 — no PUBLIC table grants
public_grants=$(psql_owner "
  SELECT COUNT(*)
  FROM information_schema.role_table_grants
  WHERE grantee = 'PUBLIC' AND table_schema = 'public'
" 2>/dev/null || echo "1")
if [[ "${public_grants}" == "0" ]]; then
  log_ok "no PUBLIC table grants"
else
  log_fail "PUBLIC table grants count=${public_grants}"
fi

if [[ "${failures}" -gt 0 ]]; then
  echo "verify_rbac: ${failures} check(s) failed" >&2
  exit 1
fi

echo "verify_rbac: all checks passed"
