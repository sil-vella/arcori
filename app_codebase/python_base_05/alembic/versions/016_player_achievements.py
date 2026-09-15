"""Alembic migration — player_achievements + avari win streaks."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "016_player_achievements"
down_revision = "015_series_token_ser"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "avari_profiles",
        sa.Column(
            "win_streak_current",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "avari_profiles",
        sa.Column(
            "win_streak_best",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )

    op.create_table(
        "player_achievements",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("achievement_id", sa.String(length=64), nullable=False),
        sa.Column(
            "unlocked_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "user_id",
            "achievement_id",
            name="uq_player_achievements_user_achievement",
        ),
    )
    op.create_index(
        "ix_player_achievements_user_id",
        "player_achievements",
        ["user_id"],
    )
    op.create_index(
        "ix_player_achievements_achievement_id",
        "player_achievements",
        ["achievement_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_player_achievements_achievement_id",
        table_name="player_achievements",
    )
    op.drop_index("ix_player_achievements_user_id", table_name="player_achievements")
    op.drop_table("player_achievements")
    op.drop_column("avari_profiles", "win_streak_best")
    op.drop_column("avari_profiles", "win_streak_current")
