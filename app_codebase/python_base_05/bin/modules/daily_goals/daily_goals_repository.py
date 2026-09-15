"""Persistence for player_daily_goal_progress."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from models.player_progress import PlayerDailyGoalProgress


def _as_uuid(user_id: str | uuid.UUID) -> uuid.UUID:
    if isinstance(user_id, uuid.UUID):
        return user_id
    return uuid.UUID(str(user_id))


def list_progress_rows(
    session: Session, user_id: str | uuid.UUID
) -> list[PlayerDailyGoalProgress]:
    uid = _as_uuid(user_id)
    stmt = select(PlayerDailyGoalProgress).where(
        PlayerDailyGoalProgress.user_id == uid
    )
    return list(session.scalars(stmt).all())


def get_progress_row(
    session: Session, user_id: str | uuid.UUID, goal_id: str
) -> PlayerDailyGoalProgress | None:
    uid = _as_uuid(user_id)
    gid = (goal_id or "").strip()
    if not gid:
        return None
    stmt = select(PlayerDailyGoalProgress).where(
        PlayerDailyGoalProgress.user_id == uid,
        PlayerDailyGoalProgress.goal_id == gid,
    )
    return session.scalars(stmt).first()


def ensure_progress_row(
    session: Session, *, user_id: str | uuid.UUID, goal_id: str
) -> PlayerDailyGoalProgress:
    uid = _as_uuid(user_id)
    gid = (goal_id or "").strip()
    existing = get_progress_row(session, uid, gid)
    if existing is not None:
        return existing
    row = PlayerDailyGoalProgress(
        id=uuid.uuid4(),
        user_id=uid,
        goal_id=gid,
        value=0,
        day_key=None,
        progress_today=0,
        completed_today=False,
        miss_pending=False,
        last_completed_day_key=None,
    )
    session.add(row)
    session.flush()
    return row


def upsert_progress_row(
    session: Session, *, user_id: str | uuid.UUID, goal_id: str
) -> PlayerDailyGoalProgress:
    """Insert-or-get under concurrent create (unique constraint)."""
    uid = _as_uuid(user_id)
    gid = (goal_id or "").strip()
    stmt = (
        insert(PlayerDailyGoalProgress)
        .values(
            id=uuid.uuid4(),
            user_id=uid,
            goal_id=gid,
            value=0,
            day_key=None,
            progress_today=0,
            completed_today=False,
            miss_pending=False,
            last_completed_day_key=None,
        )
        .on_conflict_do_nothing(
            constraint="uq_player_daily_goal_progress_user_goal"
        )
    )
    session.execute(stmt)
    session.flush()
    row = get_progress_row(session, uid, gid)
    assert row is not None
    return row
