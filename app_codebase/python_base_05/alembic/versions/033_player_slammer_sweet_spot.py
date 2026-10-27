"""Alembic — per-player slammer sweet spot on player_slammers."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "033_player_slammer_sweet_spot"
down_revision = "032_design_id_type_token"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "player_slammers",
        sa.Column(
            "sweet_spot",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("player_slammers", "sweet_spot")
