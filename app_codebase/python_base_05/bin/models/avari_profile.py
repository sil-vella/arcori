"""1:1 Avari profile row for a user (Rank, economy, stats, onboarding)."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, func, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base, CreatedAtMixin, UUIDPrimaryKeyMixin


class AvariProfile(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "avari_profiles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    display_name: Mapped[str] = mapped_column(String(64), nullable=False)
    primary_title: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        default="Avari",
        server_default="Avari",
    )
    titles: Mapped[list] = mapped_column(
        JSONB,
        nullable=False,
        default=list,
        server_default=text("'[\"Avari\"]'::jsonb"),
    )
    rank_xp: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    rank_level: Mapped[int] = mapped_column(Integer, nullable=False, default=1, server_default="1")
    rank_label: Mapped[str | None] = mapped_column(String(64), nullable=True)
    gold_fragments: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    gold_caps: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    matches_played: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    wins: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    flips: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    onboarding_completed: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    onboarding_kin_chosen: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    onboarding_genesis_created: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    onboarding_starter_granted: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    onboarding_guided_practice_done: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    onboarding_intros_done: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    daily_login_streak: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    daily_last_login_reward_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    daily_cache_claimed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    daily_no_miss_streak: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    notifications_push: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default="true"
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
