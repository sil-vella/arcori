"""PostgreSQL connection settings from environment."""

from __future__ import annotations

import os


def _truthy(name: str, default: str = "0") -> bool:
    return os.environ.get(name, default).strip().lower() in ("1", "true", "yes")


def pg_rbac_enabled() -> bool:
    """When true, runtime uses app role; migrations use owner URL."""
    return _truthy("PG_RBAC_ENABLED", "0")


def database_url() -> str:
    return os.environ.get("DATABASE_URL", "").strip()


def migration_database_url() -> str:
    """Owner URL for Alembic, role bootstrap, and operator seed scripts."""
    url = os.environ.get("MIGRATION_DATABASE_URL", "").strip()
    if url:
        return url
    return database_url()


def readonly_database_url() -> str:
    return os.environ.get("READONLY_DATABASE_URL", "").strip()


def _to_sqlalchemy_url(url: str) -> str:
    if not url:
        return url
    if url.startswith("postgresql://"):
        return url.replace("postgresql://", "postgresql+psycopg://", 1)
    if url.startswith("postgres://"):
        return url.replace("postgres://", "postgresql+psycopg://", 1)
    return url


def sqlalchemy_database_url() -> str:
    """Return a SQLAlchemy-compatible URL (postgresql+psycopg) for runtime."""
    return _to_sqlalchemy_url(database_url())


def sqlalchemy_migration_database_url() -> str:
    """SQLAlchemy URL for migrations and DDL."""
    return _to_sqlalchemy_url(migration_database_url())
