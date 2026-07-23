"""SQLAlchemy access for users."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from models.user import User


def create_user(
    session: Session,
    *,
    username: str,
    email: str,
    password_hash: str,
    is_guest: bool,
) -> User:
    row = User(
        username=username,
        email=email,
        password_hash=password_hash,
        is_guest=is_guest,
    )
    session.add(row)
    session.flush()
    return row


def find_by_email(session: Session, email: str) -> User | None:
    stmt = select(User).where(User.email == email)
    return session.scalars(stmt).first()


def find_by_username(session: Session, username: str) -> User | None:
    stmt = select(User).where(User.username == username)
    return session.scalars(stmt).first()


def find_by_id(session: Session, user_id: str) -> User | None:
    try:
        uid = uuid.UUID(user_id)
    except ValueError:
        return None
    stmt = select(User).where(User.id == uid)
    return session.scalars(stmt).first()


def email_taken_by_other(
    session: Session,
    email: str,
    exclude_user_id: str,
) -> bool:
    existing = find_by_email(session, email)
    if existing is None:
        return False
    return str(existing.id) != exclude_user_id


def username_taken_by_other(
    session: Session,
    username: str,
    exclude_user_id: str,
) -> bool:
    existing = find_by_username(session, username)
    if existing is None:
        return False
    return str(existing.id) != exclude_user_id


def upgrade_guest_to_full(
    session: Session,
    user_id: str,
    *,
    username: str,
    email: str,
    password_hash: str,
) -> User:
    user = find_by_id(session, user_id)
    if user is None:
        raise ValueError(f"user not found: {user_id}")
    user.username = username
    user.email = email
    user.password_hash = password_hash
    user.is_guest = False
    user.email_verified_at = None
    session.flush()
    return user


def delete_by_id(session: Session, user_id: str) -> bool:
    user = find_by_id(session, user_id)
    if user is None:
        return False
    session.delete(user)
    return True
