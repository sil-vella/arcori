"""Player achievements DB reads/writes."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from models.player_progress import PlayerAchievement


def _as_uuid(user_id: str) -> uuid.UUID | None:
    try:
        return uuid.UUID(user_id)
    except ValueError:
        return None


def list_unlocked_ids(session: Session, user_id: str) -> list[str]:
    uid = _as_uuid(user_id)
    if uid is None:
        return []
    rows = session.scalars(
        select(PlayerAchievement.achievement_id)
        .where(PlayerAchievement.user_id == uid)
        .order_by(PlayerAchievement.unlocked_at.asc())
    ).all()
    return [str(r) for r in rows if str(r).strip()]


def unlocked_id_set(session: Session, user_id: str) -> set[str]:
    return set(list_unlocked_ids(session, user_id))


def insert_unlocks(
    session: Session,
    *,
    user_id: str,
    achievement_ids: list[str],
) -> list[str]:
    """Insert new unlocks; return ids that were newly inserted (idempotent)."""
    uid = _as_uuid(user_id)
    if uid is None or not achievement_ids:
        return []
    inserted: list[str] = []
    for aid in achievement_ids:
        key = (aid or "").strip()
        if not key:
            continue
        stmt = (
            insert(PlayerAchievement)
            .values(
                id=uuid.uuid4(),
                user_id=uid,
                achievement_id=key,
            )
            .on_conflict_do_nothing(
                constraint="uq_player_achievements_user_achievement"
            )
            .returning(PlayerAchievement.achievement_id)
        )
        row = session.execute(stmt).first()
        if row is not None:
            inserted.append(str(row[0]))
    return inserted
