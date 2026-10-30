"""Ledger of verified Play and App Store fragment grants."""

from __future__ import annotations

import uuid

from sqlalchemy import Boolean, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base, CreatedAtMixin, UUIDPrimaryKeyMixin


class StoreFragmentPurchase(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "store_fragment_purchases"
    __table_args__ = (
        UniqueConstraint(
            "platform",
            "store_ref",
            name="uq_store_fragment_purchase_ref",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    platform: Mapped[str] = mapped_column(String(16), nullable=False)
    product_id: Mapped[str] = mapped_column(String(64), nullable=False)
    store_ref: Mapped[str] = mapped_column(Text, nullable=False)
    fragments_credited: Mapped[int] = mapped_column(Integer, nullable=False)
    order_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    consume_ok: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
