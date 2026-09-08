"""Alembic migration — player_kin.catalog_design JSONB (mirrored Arcori design)."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision = "013_player_kin_catalog_design"
down_revision = "012_contacts"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "player_kin",
        sa.Column(
            "catalog_design",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("player_kin", "catalog_design")
