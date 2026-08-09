"""Alembic migration environment."""

from __future__ import annotations

import sys
from logging.config import fileConfig
from pathlib import Path

from alembic import context
from sqlalchemy import engine_from_config, pool

# Ensure bin/ is on sys.path for model imports.
_bin_root = Path(__file__).resolve().parents[1] / "bin"
if str(_bin_root) not in sys.path:
    sys.path.insert(0, str(_bin_root))

from core.db.db_config import sqlalchemy_migration_database_url  # noqa: E402
from models import Base  # noqa: E402
import models.platform_meta  # noqa: E402, F401
import models.user  # noqa: E402, F401
import models.login_event  # noqa: E402, F401
import models.user_notification  # noqa: E402, F401
import models.global_notification  # noqa: E402, F401
import models.global_notification_read  # noqa: E402, F401
import models.ops_runtime  # noqa: E402, F401
import models.design_standing  # noqa: E402, F401
import models.avari_profile  # noqa: E402, F401
import models.player_progress  # noqa: E402, F401
import models.example_module_record  # noqa: E402, F401

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def get_url() -> str:
    url = sqlalchemy_migration_database_url()
    if not url:
        raise RuntimeError(
            "MIGRATION_DATABASE_URL or DATABASE_URL must be set for Alembic migrations"
        )
    return url


def run_migrations_offline() -> None:
    context.configure(
        url=get_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    configuration = config.get_section(config.config_ini_section) or {}
    configuration["sqlalchemy.url"] = get_url()
    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
