"""Contacts module service functions (username search + mutual contacts)."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import and_, delete, func, or_, select
from sqlalchemy.dialects.postgresql import insert as pg_insert

from core.errors.app_error import AppError
from core.state.session_scope import session_scope
from core.utils.dev_logger import customlog
from models.avari_profile import AvariProfile
from models.user import User
from models.user_contact import UserContact
from modules.contacts.contacts_errors import (
    FORBIDDEN,
    INVALID_REQUEST,
    NOT_FOUND,
)


def _parse_uuid(raw: Any, *, field: str) -> uuid.UUID:
    if raw is None:
        raise AppError(INVALID_REQUEST, message=f"{field} is required")
    try:
        return uuid.UUID(str(raw).strip())
    except ValueError as exc:
        raise AppError(INVALID_REQUEST, message=f"{field} must be a UUID") from exc


def search_users_by_username(
    *,
    user_id: uuid.UUID,
    query: str,
    limit: int = 20,
) -> list[dict[str, Any]]:
    q = (query or "").strip()
    if len(q) < 2:
        raise AppError(INVALID_REQUEST, message="query must be at least 2 chars")

    q_lower = q.lower()
    q_like = f"%{q_lower}%"

    with session_scope() as session:
        stmt = (
            select(User.id, User.username, AvariProfile.display_name)
            .outerjoin(AvariProfile, AvariProfile.user_id == User.id)
            .where(
                User.id != user_id,
                func.lower(User.username).like(q_like),
            )
            .order_by(func.lower(User.username))
            .limit(limit)
        )
        rows = list(session.execute(stmt).all())

    results: list[dict[str, Any]] = []
    for other_id, username, display_name in rows:
        results.append(
            {
                "userId": str(other_id),
                "username": username,
                "displayName": str(display_name) if display_name else username,
            }
        )
    return results


def list_contacts_for_user(*, user_id: uuid.UUID) -> list[dict[str, Any]]:
    with session_scope() as session:
        stmt = (
            select(
                UserContact.contact_user_id,
                User.username,
                AvariProfile.display_name,
            )
            .join(User, User.id == UserContact.contact_user_id)
            .outerjoin(
                AvariProfile,
                AvariProfile.user_id == UserContact.contact_user_id,
            )
            .where(UserContact.user_id == user_id)
            .order_by(func.lower(User.username))
        )
        rows = list(session.execute(stmt).all())

    results: list[dict[str, Any]] = []
    for contact_user_id, username, display_name in rows:
        results.append(
            {
                "userId": str(contact_user_id),
                "username": username,
                "displayName": str(display_name) if display_name else username,
            }
        )
    return results


def add_contact_mutual(*, user_id: uuid.UUID, contact_user_id: uuid.UUID) -> None:
    if contact_user_id == user_id:
        raise AppError(FORBIDDEN, message="Cannot contact yourself")

    with session_scope() as session:
        contact_exists = session.scalar(
            select(User.id).where(User.id == contact_user_id)
        )
        if contact_exists is None:
            raise AppError(NOT_FOUND, message="User not found")

        now_stmt = [
            pg_insert(UserContact)
            .values(user_id=user_id, contact_user_id=contact_user_id)
            .on_conflict_do_nothing(index_elements=["user_id", "contact_user_id"]),
            pg_insert(UserContact)
            .values(user_id=contact_user_id, contact_user_id=user_id)
            .on_conflict_do_nothing(index_elements=["user_id", "contact_user_id"]),
        ]
        for stmt in now_stmt:
            session.execute(stmt)

        session.flush()

    if LOGGING_SWITCH:
        customlog(
            f"contacts: add mutual me={user_id} other={contact_user_id}"
        )


def remove_contact_mutual(*, user_id: uuid.UUID, contact_user_id: uuid.UUID) -> None:
    with session_scope() as session:
        stmt = delete(UserContact).where(
            or_(
                and_(
                    UserContact.user_id == user_id,
                    UserContact.contact_user_id == contact_user_id,
                ),
                and_(
                    UserContact.user_id == contact_user_id,
                    UserContact.contact_user_id == user_id,
                ),
            )
        )
        session.execute(stmt)
        session.flush()


# Keep consistent with other modules; logging is off by default.
LOGGING_SWITCH = True

