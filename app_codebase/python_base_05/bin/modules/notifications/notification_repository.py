"""SQLAlchemy access for notification tables."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import and_, desc, func, or_, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from models.global_notification import GlobalNotification
from models.global_notification_read import GlobalNotificationRead
from models.user_notification import (
    NOTIFICATION_TYPES,
    UserNotification,
)


def insert_user_notification(
    session: Session,
    *,
    user_id: uuid.UUID,
    source: str,
    notification_type: str,
    title: str,
    body: str,
    category: str | None = None,
    subtype: str | None = None,
    msg_id: str | None = None,
    data: dict[str, Any] | None = None,
    responses: list[dict[str, Any]] | None = None,
) -> UserNotification:
    row = UserNotification(
        user_id=user_id,
        source=source.strip(),
        type=notification_type,
        category=category,
        subtype=subtype,
        msg_id=msg_id,
        title=title,
        body=body,
        data=data or {},
        responses=responses or [],
    )
    session.add(row)
    session.flush()
    return row


def list_user_notifications(
    session: Session,
    user_id: uuid.UUID,
    *,
    limit: int = 50,
    offset: int = 0,
    unread_only: bool = False,
) -> list[UserNotification]:
    conditions = [
        UserNotification.user_id == user_id,
        UserNotification.deleted_at.is_(None),
    ]
    if unread_only:
        conditions.append(UserNotification.read_at.is_(None))
    stmt = (
        select(UserNotification)
        .where(and_(*conditions))
        .order_by(desc(UserNotification.created_at))
        .offset(offset)
        .limit(limit)
    )
    return list(session.scalars(stmt).all())


def count_unread_user_notifications(session: Session, user_id: uuid.UUID) -> int:
    stmt = (
        select(func.count())
        .select_from(UserNotification)
        .where(
            UserNotification.user_id == user_id,
            UserNotification.deleted_at.is_(None),
            UserNotification.read_at.is_(None),
        )
    )
    return int(session.scalar(stmt) or 0)


def mark_user_notifications_read(
    session: Session,
    user_id: uuid.UUID,
    message_ids: list[uuid.UUID],
) -> int:
    if not message_ids:
        return 0
    now = datetime.now(timezone.utc)
    rows = session.scalars(
        select(UserNotification).where(
            UserNotification.user_id == user_id,
            UserNotification.id.in_(message_ids),
            UserNotification.deleted_at.is_(None),
        )
    ).all()
    updated = 0
    for row in rows:
        if row.read_at is None:
            row.read_at = now
            updated += 1
    session.flush()
    return updated


def soft_delete_user_notifications(
    session: Session,
    user_id: uuid.UUID,
    message_ids: list[uuid.UUID],
) -> int:
    if not message_ids:
        return 0
    now = datetime.now(timezone.utc)
    rows = session.scalars(
        select(UserNotification).where(
            UserNotification.user_id == user_id,
            UserNotification.id.in_(message_ids),
            UserNotification.deleted_at.is_(None),
        )
    ).all()
    deleted = 0
    for row in rows:
        row.deleted_at = now
        deleted += 1
    session.flush()
    return deleted


def list_active_global_notifications(
    session: Session,
    *,
    now: datetime | None = None,
) -> list[GlobalNotification]:
    current = now or datetime.now(timezone.utc)
    stmt = select(GlobalNotification).where(
        GlobalNotification.is_active.is_(True),
        or_(GlobalNotification.starts_at.is_(None), GlobalNotification.starts_at <= current),
        or_(GlobalNotification.ends_at.is_(None), GlobalNotification.ends_at >= current),
    )
    return list(session.scalars(stmt).all())


def global_read_ids_for_user(
    session: Session,
    user_id: uuid.UUID,
    global_ids: list[uuid.UUID],
) -> set[uuid.UUID]:
    if not global_ids:
        return set()
    rows = session.scalars(
        select(GlobalNotificationRead.global_notification_id).where(
            GlobalNotificationRead.user_id == user_id,
            GlobalNotificationRead.global_notification_id.in_(global_ids),
        )
    ).all()
    return set(rows)


def mark_global_notifications_read(
    session: Session,
    user_id: uuid.UUID,
    global_ids: list[uuid.UUID],
) -> int:
    if not global_ids:
        return 0
    now = datetime.now(timezone.utc)
    count = 0
    for global_id in global_ids:
        stmt = (
            insert(GlobalNotificationRead)
            .values(
                user_id=user_id,
                global_notification_id=global_id,
                read_at=now,
            )
            .on_conflict_do_nothing(
                index_elements=["user_id", "global_notification_id"],
            )
        )
        result = session.execute(stmt)
        if result.rowcount:
            count += 1
    session.flush()
    return count


def is_valid_notification_type(value: str) -> bool:
    return value in NOTIFICATION_TYPES


def get_user_notification(
    session: Session,
    user_id: uuid.UUID,
    message_id: uuid.UUID,
) -> UserNotification | None:
    return session.scalar(
        select(UserNotification).where(
            UserNotification.user_id == user_id,
            UserNotification.id == message_id,
            UserNotification.deleted_at.is_(None),
        )
    )


def get_active_global_notification(
    session: Session,
    global_id: uuid.UUID,
    *,
    now: datetime | None = None,
) -> GlobalNotification | None:
    current = now or datetime.now(timezone.utc)
    return session.scalar(
        select(GlobalNotification).where(
            GlobalNotification.id == global_id,
            GlobalNotification.is_active.is_(True),
            or_(GlobalNotification.starts_at.is_(None), GlobalNotification.starts_at <= current),
            or_(GlobalNotification.ends_at.is_(None), GlobalNotification.ends_at >= current),
        )
    )


def list_all_global_notification_ids(session: Session) -> list[uuid.UUID]:
    rows = session.scalars(select(GlobalNotification.id)).all()
    return list(rows)


def upsert_global_notification(
    session: Session,
    *,
    global_id: uuid.UUID,
    source: str,
    notification_type: str,
    title: str,
    body: str,
    category: str | None = None,
    subtype: str | None = None,
    msg_id: str | None = None,
    data: dict[str, Any] | None = None,
    responses: list[dict[str, Any]] | None = None,
    target_audience: dict[str, Any] | None = None,
    is_active: bool = True,
    starts_at: datetime | None = None,
    ends_at: datetime | None = None,
) -> GlobalNotification:
    row = session.get(GlobalNotification, global_id)
    if row is None:
        row = GlobalNotification(id=global_id)
        session.add(row)
    row.source = source.strip()
    row.type = notification_type
    row.category = category
    row.subtype = subtype
    row.msg_id = msg_id
    row.title = title
    row.body = body
    row.data = data or {}
    row.responses = responses or []
    row.target_audience = target_audience or {"all": True}
    row.is_active = is_active
    row.starts_at = starts_at
    row.ends_at = ends_at
    session.flush()
    return row


def deactivate_global_notifications_not_in(
    session: Session,
    keep_ids: set[uuid.UUID],
) -> int:
    rows = session.scalars(select(GlobalNotification)).all()
    count = 0
    for row in rows:
        if row.id not in keep_ids and row.is_active:
            row.is_active = False
            count += 1
    session.flush()
    return count
