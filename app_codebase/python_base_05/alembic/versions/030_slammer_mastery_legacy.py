"""Alembic — slammer mastery + legacy seal fields on player_slammers."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "030_slammer_mastery_legacy"
down_revision = "029_player_mastery_change_log"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "player_slammers",
        sa.Column(
            "mastery_points",
            sa.Numeric(12, 4),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "player_slammers",
        sa.Column(
            "matches_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "player_slammers",
        sa.Column(
            "successful_slams",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "player_slammers",
        sa.Column(
            "arcori_flipped",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "player_slammers",
        sa.Column(
            "best_slam",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "player_slammers",
        sa.Column("legacy_id", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "player_slammers",
        sa.Column(
            "legacy_snapshot",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_player_slammers_legacy_id",
        "player_slammers",
        ["legacy_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_player_slammers_legacy_id", table_name="player_slammers")
    op.drop_column("player_slammers", "legacy_snapshot")
    op.drop_column("player_slammers", "legacy_id")
    op.drop_column("player_slammers", "best_slam")
    op.drop_column("player_slammers", "arcori_flipped")
    op.drop_column("player_slammers", "successful_slams")
    op.drop_column("player_slammers", "matches_count")
    op.drop_column("player_slammers", "mastery_points")
