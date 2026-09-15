"""Alembic migration — special event match credit columns."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "019_special_event_match_credit"
down_revision = "018_special_event_progress"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "player_special_event_progress",
        sa.Column(
            "matches_completed",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "player_special_event_progress",
        sa.Column(
            "matches_won",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "player_special_event_progress",
        sa.Column(
            "matches_credited",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "player_special_event_progress",
        sa.Column("last_match_id", sa.String(length=128), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("player_special_event_progress", "last_match_id")
    op.drop_column("player_special_event_progress", "matches_credited")
    op.drop_column("player_special_event_progress", "matches_won")
    op.drop_column("player_special_event_progress", "matches_completed")
