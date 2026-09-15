"""Alembic migration — player_special_event_progress."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "018_special_event_progress"
down_revision = "017_player_daily_goal_progress"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "player_special_event_progress",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("event_id", sa.String(length=64), nullable=False),
        sa.Column("flips", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "flipped_design_ids",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
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
            "event_id",
            name="uq_player_special_event_progress_user_event",
        ),
    )
    op.create_index(
        "ix_player_special_event_progress_user_id",
        "player_special_event_progress",
        ["user_id"],
    )
    op.create_index(
        "ix_player_special_event_progress_event_id",
        "player_special_event_progress",
        ["event_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_player_special_event_progress_event_id",
        table_name="player_special_event_progress",
    )
    op.drop_index(
        "ix_player_special_event_progress_user_id",
        table_name="player_special_event_progress",
    )
    op.drop_table("player_special_event_progress")
