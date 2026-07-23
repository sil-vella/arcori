"""Integration checks for Postgres RBAC app role (requires live DB + PG_RBAC_ENABLED=1)."""

from __future__ import annotations

import os

import psycopg
import pytest

from core.db.db_config import database_url, pg_rbac_enabled


pytestmark = pytest.mark.skipif(
    not pg_rbac_enabled(),
    reason="PG_RBAC_ENABLED is not 1",
)


def test_app_role_cannot_create_table() -> None:
    url = database_url()
    assert url
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        with psycopg.connect(url, autocommit=True) as conn:
            conn.execute("CREATE TABLE rbac_pytest_probe (id int)")


def test_app_role_can_select_platform_meta() -> None:
    url = database_url()
    with psycopg.connect(url) as conn:
        row = conn.execute("SELECT 1 FROM platform_meta LIMIT 1").fetchone()
    assert row is not None
    assert row[0] == 1
