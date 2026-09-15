"""Alembic migration — player_daily_goal_progress."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "017_player_daily_goal_progress"
down_revision = "016_player_achievements"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "player_daily_goal_progress",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("goal_id", sa.String(length=64), nullable=False),
        sa.Column("value", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("day_key", sa.String(length=16), nullable=True),
        sa.Column("progress_today", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "completed_today",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
        sa.Column(
            "miss_pending",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
        sa.Column("last_completed_day_key", sa.String(length=16), nullable=True),
        sa.Column(
            "updated_at",
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
            "goal_id",
            name="uq_player_daily_goal_progress_user_goal",
        ),
    )
    op.create_index(
        "ix_player_daily_goal_progress_user_id",
        "player_daily_goal_progress",
        ["user_id"],
    )
    op.create_index(
        "ix_player_daily_goal_progress_goal_id",
        "player_daily_goal_progress",
        ["goal_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_player_daily_goal_progress_goal_id",
        table_name="player_daily_goal_progress",
    )
    op.drop_index(
        "ix_player_daily_goal_progress_user_id",
        table_name="player_daily_goal_progress",
    )
    op.drop_table("player_daily_goal_progress")
