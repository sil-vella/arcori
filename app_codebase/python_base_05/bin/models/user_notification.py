"""User inbox notification rows."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base, CreatedAtMixin, UUIDPrimaryKeyMixin

NOTIFICATION_TYPE_INSTANT = "instant"
NOTIFICATION_TYPE_INBOX = "inbox"
NOTIFICATION_TYPES = frozenset({NOTIFICATION_TYPE_INSTANT, NOTIFICATION_TYPE_INBOX})


class UserNotification(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "user_notifications"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    source: Mapped[str] = mapped_column(String(64), nullable=False)
    type: Mapped[str] = mapped_column(String(16), nullable=False)
    category: Mapped[str | None] = mapped_column(String(64), nullable=True)
    subtype: Mapped[str | None] = mapped_column(String(128), nullable=True)
    msg_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    title: Mapped[str] = mapped_column(String(512), nullable=False)
    body: Mapped[str] = mapped_column(Text(), nullable=False)
    data: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    responses: Mapped[list] = mapped_column(JSONB, nullable=False, default=list)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
