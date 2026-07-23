"""Persist login audit rows."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from models.login_event import LoginEvent


def record_login_event(
    session: Session,
    *,
    user_id: str,
    client_ip: str | None,
    user_agent: str | None,
) -> LoginEvent:
    row = LoginEvent(
        user_id=uuid.UUID(user_id),
        client_ip=client_ip,
        user_agent=user_agent,
    )
    session.add(row)
    session.flush()
    return row


def list_for_user(
    session: Session,
    user_id: str,
    *,
    limit: int = 50,
) -> list[LoginEvent]:
    uid = uuid.UUID(user_id)
    stmt = (
        select(LoginEvent)
        .where(LoginEvent.user_id == uid)
        .order_by(LoginEvent.created_at.desc())
        .limit(limit)
    )
    return list(session.scalars(stmt).all())
