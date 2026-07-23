"""Sentinel table used to verify Alembic migrations have been applied."""

from __future__ import annotations

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base


class PlatformMeta(Base):
    __tablename__ = "platform_meta"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    schema_version: Mapped[str] = mapped_column(String(64), nullable=False, default="1")
