"""Single-row runtime ops flags shared across Gunicorn workers."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, func
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base


class OpsRuntime(Base):
    __tablename__ = "ops_runtime"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    drain_mode: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
