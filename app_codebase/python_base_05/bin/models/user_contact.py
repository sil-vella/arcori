"""Mutual contacts between users (stored as two directed rows)."""

from __future__ import annotations

import uuid

from sqlalchemy import CheckConstraint, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base, CreatedAtMixin, UUIDPrimaryKeyMixin


class UserContact(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "user_contacts"

    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    contact_user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "contact_user_id",
            name="uq_user_contacts_user_contact",
        ),
        CheckConstraint(
            "user_id <> contact_user_id",
            name="ck_user_contacts_not_self",
        ),
    )

