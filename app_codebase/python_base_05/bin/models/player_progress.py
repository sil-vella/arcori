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
