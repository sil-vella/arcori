"""Tests for database URL helpers."""

from __future__ import annotations

import os

import pytest

from core.db import db_config


@pytest.fixture(autouse=True)
def _clear_db_env(monkeypatch: pytest.MonkeyPatch) -> None:
    for key in (
        "DATABASE_URL",
        "MIGRATION_DATABASE_URL",
        "READONLY_DATABASE_URL",
        "PG_RBAC_ENABLED",
    ):
        monkeypatch.delenv(key, raising=False)


def test_pg_rbac_disabled_by_default() -> None:
    assert db_config.pg_rbac_enabled() is False


def test_pg_rbac_enabled_when_set(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("PG_RBAC_ENABLED", "1")
    assert db_config.pg_rbac_enabled() is True


def test_migration_url_falls_back_to_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql://u:p@host/db")
    assert db_config.migration_database_url() == "postgresql://u:p@host/db"


def test_migration_url_prefers_explicit(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql://app:pass@host/db")
    monkeypatch.setenv("MIGRATION_DATABASE_URL", "postgresql://owner:pass@host/db")
    assert db_config.migration_database_url() == "postgresql://owner:pass@host/db"


def test_sqlalchemy_migration_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("MIGRATION_DATABASE_URL", "postgresql://owner:pass@host/db")
    assert (
        db_config.sqlalchemy_migration_database_url()
        == "postgresql+psycopg://owner:pass@host/db"
    )
