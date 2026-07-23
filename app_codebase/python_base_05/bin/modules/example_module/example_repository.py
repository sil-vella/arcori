"""SQLAlchemy access for example_module_records."""

from __future__ import annotations

from typing import Any

from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from models.example_module_record import ExampleModuleRecord


def insert_record(
    session: Session,
    *,
    user_id: str,
    revision: int,
    payload: dict[str, Any],
) -> ExampleModuleRecord:
    row = ExampleModuleRecord(
        user_id=user_id,
        revision=revision,
        payload=payload,
    )
    session.add(row)
    session.flush()
    return row


def list_for_user(session: Session, user_id: str, *, limit: int = 20) -> list[ExampleModuleRecord]:
    stmt = (
        select(ExampleModuleRecord)
        .where(ExampleModuleRecord.user_id == user_id)
        .order_by(desc(ExampleModuleRecord.created_at))
        .limit(limit)
    )
    return list(session.scalars(stmt).all())
