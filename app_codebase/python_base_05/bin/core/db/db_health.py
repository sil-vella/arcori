"""PostgreSQL connectivity and schema readiness checks."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import psycopg
from alembic.config import Config
from alembic.script import ScriptDirectory

from core.db.db_config import database_url

# Fallback when alembic.ini is unavailable (tests / odd cwd).
ALEMBIC_HEAD_REVISION = "008_ops_runtime"
SENTINEL_TABLE = "platform_meta"


@dataclass(frozen=True)
class DatabaseHealth:
    db: str
    schema: str

    @property
    def is_ready(self) -> bool:
        return self.db == "ok" and self.schema == "ok"


def _expected_alembic_head() -> str:
    root = Path(__file__).resolve().parents[3]
    ini_path = root / "alembic.ini"
    alembic_dir = root / "alembic"
    if not ini_path.is_file() or not alembic_dir.is_dir():
        return ALEMBIC_HEAD_REVISION
    cfg = Config(str(ini_path))
    cfg.set_main_option("script_location", str(alembic_dir))
    script = ScriptDirectory.from_config(cfg)
    head = script.get_current_head()
    return head or ALEMBIC_HEAD_REVISION


def ping_database() -> bool:
    url = database_url()
    if not url:
        return False
    try:
        with psycopg.connect(url, connect_timeout=3) as conn:
            conn.execute("SELECT 1")
        return True
    except Exception:
        return False


def _schema_is_migrated(conn: psycopg.Connection) -> bool:
    row = conn.execute(
        """
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = %s
        )
        """,
        (SENTINEL_TABLE,),
    ).fetchone()
    if row is None or not row[0]:
        return False

    version_row = conn.execute(
        """
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = 'alembic_version'
        )
        """
    ).fetchone()
    if version_row is None or not version_row[0]:
        return False

    head = conn.execute(
        "SELECT version_num FROM alembic_version LIMIT 1"
    ).fetchone()
    expected = _expected_alembic_head()
    return head is not None and head[0] == expected


def check_database_health() -> DatabaseHealth:
    url = database_url()
    if not url:
        return DatabaseHealth(db="unavailable", schema="unavailable")

    try:
        with psycopg.connect(url, connect_timeout=3) as conn:
            conn.execute("SELECT 1")
            if _schema_is_migrated(conn):
                return DatabaseHealth(db="ok", schema="ok")
            return DatabaseHealth(db="ok", schema="unavailable")
    except Exception:
        return DatabaseHealth(db="unavailable", schema="unavailable")
