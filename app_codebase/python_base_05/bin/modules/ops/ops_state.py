"""Postgres-backed drain_mode flag (shared across Gunicorn workers)."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select

from core.state.session_scope import session_scope
from models.ops_runtime import OpsRuntime

_ROW_ID = 1


def is_drain_mode() -> bool:
    try:
        with session_scope() as session:
            row = session.get(OpsRuntime, _ROW_ID)
            if row is None:
                return False
            return bool(row.drain_mode)
    except Exception:
        return False


def set_drain_mode(enabled: bool) -> bool:
    with session_scope() as session:
        row = session.get(OpsRuntime, _ROW_ID)
        if row is None:
            row = OpsRuntime(id=_ROW_ID, drain_mode=enabled)
            session.add(row)
        else:
            row.drain_mode = enabled
            row.updated_at = datetime.now(timezone.utc)
        session.flush()
        return bool(row.drain_mode)


def ensure_ops_runtime_row() -> None:
    """Idempotent seed for tests / greenfield without migration seed."""
    with session_scope() as session:
        row = session.execute(
            select(OpsRuntime).where(OpsRuntime.id == _ROW_ID)
        ).scalar_one_or_none()
        if row is None:
            session.add(OpsRuntime(id=_ROW_ID, drain_mode=False))
