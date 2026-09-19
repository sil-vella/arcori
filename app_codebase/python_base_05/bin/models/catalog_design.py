"""Catalog designs stored in Postgres — runtime SSOT for Velora / match / Legacy."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base, CreatedAtMixin

SOURCE_SEED = "seed"
SOURCE_IMPORT = "import"
SOURCE_ECHO = "echo"

WORLD_ACTIVE = "Active"
WORLD_CLOSED = "Closed"


class CatalogDesign(Base, CreatedAtMixin):
    __tablename__ = "catalog_designs"

    internal_id: Mapped[str] = mapped_column(String(96), primary_key=True)
    series_key: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    theme: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    theme_code: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    design_code: Mapped[str] = mapped_column(String(32), nullable=False, default="")
    generation_number: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    world_state: Mapped[str] = mapped_column(
        String(16), nullable=False, default=WORLD_ACTIVE, index=True
    )
    design_json: Mapped[dict] = mapped_column(JSONB, nullable=False)
    source: Mapped[str] = mapped_column(String(16), nullable=False, default=SOURCE_SEED)
    parent_internal_id: Mapped[str | None] = mapped_column(String(96), nullable=True)
    catalog_version: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
