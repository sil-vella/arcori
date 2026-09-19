"""Legacy preserve lifecycle, intents, fulfill ledger, museum closed gens."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base, CreatedAtMixin, UUIDPrimaryKeyMixin

PHASE_RACING = "racing"
PHASE_FIRST_OFFER = "first_offer"
PHASE_LEADER_WINDOW = "leader_window"
PHASE_PRESERVED = "preserved"
PHASE_LOST_CLOSED = "lost_closed"

LEGACY_NONE = "none"
LEGACY_PRESERVED = "preserved"
LEGACY_LOST = "lost"

INTENT_PENDING = "pending"
INTENT_FULFILLED = "fulfilled"
INTENT_CANCELLED = "cancelled"


class DesignGenerationLifecycle(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Per-design generation Legacy state machine."""

    __tablename__ = "design_generation_lifecycle"
    __table_args__ = (
        UniqueConstraint(
            "design_id",
            "generation_number",
            name="uq_design_gen_lifecycle_design_gen",
        ),
    )

    design_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    generation_number: Mapped[int] = mapped_column(Integer, nullable=False)
    phase: Mapped[str] = mapped_column(
        String(32), nullable=False, default=PHASE_RACING, server_default=PHASE_RACING
    )
    first_offer_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    first_offer_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    leader_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    leader_since: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    leader_window_ends_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    preservation_requirement: Mapped[int] = mapped_column(
        Integer, nullable=False, default=500
    )
    closure_milestone: Mapped[int] = mapped_column(
        Integer, nullable=False, default=1000
    )
    preserved_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    closed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    legacy_state: Mapped[str] = mapped_column(
        String(16), nullable=False, default=LEGACY_NONE, server_default=LEGACY_NONE
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class LegacyPreserveIntent(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Pending external checkout for a preserve attempt."""

    __tablename__ = "legacy_preserve_intent"
    __table_args__ = (
        UniqueConstraint("intent_id", name="uq_legacy_preserve_intent_intent_id"),
    )

    intent_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    design_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    generation_number: Mapped[int] = mapped_column(Integer, nullable=False)
    # Optional batch: [{ "designId", "generationNumber" }, ...] — when set, checkout
    # covers every item; design_id/generation_number stay as the first for indexes.
    items_json: Mapped[dict | list | None] = mapped_column(JSONB, nullable=True)
    checkout_status: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default=INTENT_PENDING,
        server_default=INTENT_PENDING,
    )
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class LegacyFulfillLedger(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """Idempotent website order → mint fulfillment."""

    __tablename__ = "legacy_fulfill_ledger"
    __table_args__ = (
        UniqueConstraint("order_id", name="uq_legacy_fulfill_ledger_order_id"),
    )

    order_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    intent_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    design_id: Mapped[str] = mapped_column(String(64), nullable=False)
    generation_number: Mapped[int] = mapped_column(Integer, nullable=False)
    response_json: Mapped[dict] = mapped_column(JSONB, nullable=False)


class MuseumGeneration(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    """World history of closed generations (Museum — not personal Trove)."""

    __tablename__ = "museum_generations"
    __table_args__ = (
        UniqueConstraint(
            "design_id",
            "generation_number",
            name="uq_museum_generations_design_gen",
        ),
    )

    design_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    generation_number: Mapped[int] = mapped_column(Integer, nullable=False)
    legacy_state: Mapped[str] = mapped_column(
        String(16), nullable=False, index=True
    )
    preserved_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    closed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )
    meta_json: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
