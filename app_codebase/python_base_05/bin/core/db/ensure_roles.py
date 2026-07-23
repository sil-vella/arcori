"""Idempotent PostgreSQL RBAC role and grant bootstrap (owner connection)."""

from __future__ import annotations

import os
import sys

import psycopg
from psycopg import sql

from core.db.db_config import migration_database_url, pg_rbac_enabled


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def _quote_literal(value: str) -> sql.Literal:
    return sql.Literal(value)


def ensure_postgres_roles() -> None:
    """Create app/readonly roles and apply grants when PG_RBAC_ENABLED=1."""
    if not pg_rbac_enabled():
        return

    url = migration_database_url()
    if not url:
        print("ensure_roles: MIGRATION_DATABASE_URL / DATABASE_URL not set", file=sys.stderr)
        sys.exit(1)

    db_name = _env("POSTGRES_DB", "arcori")
    owner = _env("POSTGRES_USER", "arcori")
    app_user = _env("POSTGRES_APP_USER", f"{db_name}_app")
    app_password = _env("POSTGRES_APP_PASSWORD")
    readonly_user = _env("POSTGRES_READONLY_USER", f"{db_name}_readonly")
    readonly_password = _env("POSTGRES_READONLY_PASSWORD")

    if not app_password or not readonly_password:
        print(
            "ensure_roles: POSTGRES_APP_PASSWORD and POSTGRES_READONLY_PASSWORD required "
            "when PG_RBAC_ENABLED=1",
            file=sys.stderr,
        )
        sys.exit(1)

    with psycopg.connect(url, autocommit=True) as conn:
        _ensure_login_role(conn, app_user, app_password)
        _ensure_login_role(conn, readonly_user, readonly_password)
        _apply_grants(
            conn,
            db_name=db_name,
            owner=owner,
            app_user=app_user,
            readonly_user=readonly_user,
        )


def _ensure_login_role(conn: psycopg.Connection, role: str, password: str) -> None:
    exists = conn.execute(
        "SELECT 1 FROM pg_roles WHERE rolname = %s",
        (role,),
    ).fetchone()
    if exists:
        conn.execute(
            sql.SQL("ALTER ROLE {} WITH LOGIN PASSWORD {}").format(
                sql.Identifier(role),
                _quote_literal(password),
            )
        )
    else:
        conn.execute(
            sql.SQL(
                "CREATE ROLE {} LOGIN PASSWORD {} NOSUPERUSER NOCREATEDB NOCREATEROLE"
            ).format(
                sql.Identifier(role),
                _quote_literal(password),
            )
        )


def _apply_grants(
    conn: psycopg.Connection,
    *,
    db_name: str,
    owner: str,
    app_user: str,
    readonly_user: str,
) -> None:
    statements = [
        sql.SQL("REVOKE ALL ON DATABASE {} FROM PUBLIC").format(sql.Identifier(db_name)),
        sql.SQL("REVOKE ALL ON SCHEMA public FROM PUBLIC"),
        sql.SQL("REVOKE CREATE ON SCHEMA public FROM PUBLIC"),
        sql.SQL("GRANT CONNECT ON DATABASE {} TO {}").format(
            sql.Identifier(db_name),
            sql.Identifier(app_user),
        ),
        sql.SQL("GRANT CONNECT ON DATABASE {} TO {}").format(
            sql.Identifier(db_name),
            sql.Identifier(readonly_user),
        ),
        sql.SQL("GRANT USAGE ON SCHEMA public TO {}").format(sql.Identifier(app_user)),
        sql.SQL("GRANT USAGE ON SCHEMA public TO {}").format(sql.Identifier(readonly_user)),
        sql.SQL(
            "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO {}"
        ).format(sql.Identifier(app_user)),
        sql.SQL("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO {}").format(
            sql.Identifier(app_user)
        ),
        sql.SQL("GRANT SELECT ON ALL TABLES IN SCHEMA public TO {}").format(
            sql.Identifier(readonly_user)
        ),
        sql.SQL(
            "ALTER DEFAULT PRIVILEGES FOR ROLE {} IN SCHEMA public "
            "GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {}"
        ).format(sql.Identifier(owner), sql.Identifier(app_user)),
        sql.SQL(
            "ALTER DEFAULT PRIVILEGES FOR ROLE {} IN SCHEMA public "
            "GRANT USAGE, SELECT ON SEQUENCES TO {}"
        ).format(sql.Identifier(owner), sql.Identifier(app_user)),
        sql.SQL(
            "ALTER DEFAULT PRIVILEGES FOR ROLE {} IN SCHEMA public "
            "GRANT SELECT ON TABLES TO {}"
        ).format(sql.Identifier(owner), sql.Identifier(readonly_user)),
        sql.SQL("REVOKE ALL ON TABLE alembic_version FROM {}").format(
            sql.Identifier(app_user)
        ),
        sql.SQL("REVOKE ALL ON TABLE alembic_version FROM {}").format(
            sql.Identifier(readonly_user)
        ),
    ]

    for statement in statements:
        try:
            conn.execute(statement)
        except psycopg.Error as exc:
            # alembic_version may not exist on greenfield before first migration
            if "alembic_version" in str(exc):
                continue
            raise


def main() -> None:
    ensure_postgres_roles()


if __name__ == "__main__":
    main()
