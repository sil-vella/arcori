"""SQLAlchemy engine factory."""

from __future__ import annotations

from functools import lru_cache

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine

from core.db.db_config import sqlalchemy_database_url


@lru_cache(maxsize=1)
def get_engine() -> Engine:
    return create_engine(
        sqlalchemy_database_url(),
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=10,
    )
