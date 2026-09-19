"""Player progress tables: Kin, design access, mastery, slammers, trove."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base, CreatedAtMixin, UUIDPrimaryKeyMixin


class PlayerKin(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "player_kin"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    subtheme: Mapped[str] = mapped_column(String(64), nullable=False)
    style: Mapped[str] = mapped_column(String(64), nullable=False, default="Chibi")
    finish: Mapped[str] = mapped_column(String(64), nullable=False, default="Standard")
    effect: Mapped[str] = mapped_column(String(64), nullable=False, default="None")
    genesis_design_id: Mapped[str] = mapped_column(String(64), nullable=False)
    chosen_name: Mapped[str] = mapped_column(String(64), nullable=False)
    customization: Mapped[dict] = mapped_column(
        JSONB, nullable=False, default=dict, server_default=text("'{}'::jsonb")
    )
    catalog_design: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class PlayerDesignAccess(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Circulating play/mastery access — not Trove ownership."""

    __tablename__ = "player_design_access"
    __table_args__ = (
        UniqueConstraint("user_id", "design_id", name="uq_player_design_access_user_design"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    design_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    source: Mapped[str] = mapped_column(String(32), nullable=False, default="starter")


class PlayerMastery(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Mastery points on a circulating design generation."""

    __tablename__ = "player_mastery"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "design_id",
            "generation_number",
            name="uq_player_mastery_user_design_gen",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    design_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    generation_number: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    points: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class PlayerSlammer(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "player_slammers"
    __table_args__ = (
        UniqueConstraint("user_id", "design_id", name="uq_player_slammers_user_design"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    design_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    permanent: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    charges_remaining: Mapped[int | None] = mapped_column(Integer, nullable=True)
    source: Mapped[str] = mapped_column(String(32), nullable=False, default="starter")


class PlayerTrove(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Minted closed Arcori only (out of circulation)."""

    __tablename__ = "player_trove"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "design_id",
            "generation_number",
            name="uq_player_trove_user_design_gen",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    design_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    generation_number: Mapped[int] = mapped_column(Integer, nullable=False)
    minted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    legacy_title: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        default="Legacy Owner",
        server_default="Legacy Owner",
    )
    creator_attributed: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )


class PlayerClosedGeneration(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Per-player snapshot of mastery when a design generation closed (Preserved/Lost)."""

    __tablename__ = "player_closed_generations"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "design_id",
            "generation_number",
            name="uq_player_closed_generations_user_design_gen",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    design_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    generation_number: Mapped[int] = mapped_column(Integer, nullable=False)
    mastery_points: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    echo_mastery_seeded: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    echo_generation_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    legacy_state: Mapped[str] = mapped_column(String(32), nullable=False)
    echo_design_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    closed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )


class PlayerAchievement(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Lifetime unlocked achievements (lifetime, additive)."""

    __tablename__ = "player_achievements"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "achievement_id",
            name="uq_player_achievements_user_achievement",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    achievement_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    unlocked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )


class PlayerDailyGoalProgress(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Per-goal daily progress, value/streak, and miss-continue state."""

    __tablename__ = "player_daily_goal_progress"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "goal_id",
            name="uq_player_daily_goal_progress_user_goal",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    goal_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    value: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    day_key: Mapped[str | None] = mapped_column(String(16), nullable=True)
    progress_today: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    completed_today: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    miss_pending: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    last_completed_day_key: Mapped[str | None] = mapped_column(String(16), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class PlayerSpecialEventProgress(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Per-event flip count + unique flipped design ids (multi-attempt)."""

    __tablename__ = "player_special_event_progress"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "event_id",
            name="uq_player_special_event_progress_user_event",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    event_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    flips: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    flipped_design_ids: Mapped[list] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )
    matches_completed: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    matches_won: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    matches_credited: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    last_match_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class MatchFinalizeLedger(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Durable per-user match finalize — apply writers once; replay cached payload."""

    __tablename__ = "match_finalize_ledger"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "match_id",
            name="uq_match_finalize_ledger_user_match",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    match_id: Mapped[str] = mapped_column(String(128), nullable=False)
    response_json: Mapped[dict] = mapped_column(JSONB, nullable=False)


class MatchFeeLedger(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Durable per-user fee pay/refund — apply wallet once per intent+kind."""

    __tablename__ = "match_fee_ledger"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "intent_id",
            "kind",
            name="uq_match_fee_ledger_user_intent_kind",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    intent_id: Mapped[str] = mapped_column(String(64), nullable=False)
    kind: Mapped[str] = mapped_column(String(16), nullable=False)
    response_json: Mapped[dict] = mapped_column(JSONB, nullable=False)
