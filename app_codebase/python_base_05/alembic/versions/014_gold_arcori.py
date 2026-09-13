"""Alembic migration — rename avari_profiles.gold_caps → gold_arcori."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op


revision = "014_gold_arcori"
down_revision = "013_player_kin_catalog_design"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "avari_profiles",
        "gold_caps",
        new_column_name="gold_arcori",
        existing_type=sa.Integer(),
        existing_nullable=False,
        existing_server_default="0",
    )


def downgrade() -> None:
    op.alter_column(
        "avari_profiles",
        "gold_arcori",
        new_column_name="gold_caps",
        existing_type=sa.Integer(),
        existing_nullable=False,
        existing_server_default="0",
    )
