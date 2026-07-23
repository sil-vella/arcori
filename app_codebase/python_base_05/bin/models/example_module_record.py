"""Persisted example_module rows — tier 3b durable domain."""

from __future__ import annotations

from sqlalchemy import Integer, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base, CreatedAtMixin, UUIDPrimaryKeyMixin


class ExampleModuleRecord(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "example_module_records"

    user_id: Mapped[str] = mapped_column(String(128), index=True, nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
