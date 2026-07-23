#!/usr/bin/env bash
# dash Apply Postgres app/readonly roles and grants
# Idempotent RBAC bootstrap — connects as owner (MIGRATION_DATABASE_URL).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
PYTHON_BIN="${REPO_ROOT}/app_codebase/python_base_05/bin"

if [[ "${PG_RBAC_ENABLED:-0}" != "1" ]]; then
  echo "PG_RBAC_ENABLED is not 1 — skipping apply_roles (single-user mode)."
  exit 0
fi

if [[ -z "${MIGRATION_DATABASE_URL:-}" && -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: MIGRATION_DATABASE_URL or DATABASE_URL must be set" >&2
  exit 1
fi

export PYTHONPATH="${PYTHON_BIN}${PYTHONPATH:+:${PYTHONPATH}}"
exec python3 -m core.db.ensure_roles
