"""Persisted per-design standings (active generation community state)."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.base import Base, CreatedAtMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    pass


class DesignStandingRank(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "design_standings_ranks"

    standing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("design_standings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    rank: Mapped[int] = mapped_column(Integer, nullable=False)
    display_label: Mapped[str] = mapped_column(String(128), nullable=False)
    mastery_points: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    standing: Mapped[DesignStanding] = relationship(back_populates="ranks")


class DesignStanding(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "design_standings"
    __table_args__ = (
        UniqueConstraint(
            "internal_id",
            "generation_number",
            name="uq_design_standings_internal_gen",
        ),
    )

    internal_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    generation_number: Mapped[int] = mapped_column(Integer, nullable=False)
    generation_roman: Mapped[str | None] = mapped_column(String(16), nullable=True)
    fill_current: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    fill_cap: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    leader_window_ends_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    ranks: Mapped[list[DesignStandingRank]] = relationship(
        back_populates="standing",
        cascade="all, delete-orphan",
        order_by=DesignStandingRank.rank,
    )
