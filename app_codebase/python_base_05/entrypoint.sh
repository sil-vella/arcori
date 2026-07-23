#!/usr/bin/env sh
set -e
cd /app
MIGRATION_DATABASE_URL="${MIGRATION_DATABASE_URL:-$DATABASE_URL}" alembic upgrade head
if [ "${PG_RBAC_ENABLED:-0}" = "1" ]; then
  PYTHONPATH=/app/bin python -m core.db.ensure_roles
fi
cd /app/bin
exec gunicorn -c ../gunicorn.conf.py asgi:app
