"""Alembic — player_mastery_change_log for Home ticker."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "029_player_mastery_change_log"
down_revision = "028_closed_gen_echo_seed"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "player_mastery_change_log",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("design_id", sa.String(length=64), nullable=False),
        sa.Column("generation_number", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("delta_points", sa.Integer(), nullable=False),
        sa.Column("total_points", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("display_name", sa.String(length=128), nullable=True),
        sa.Column("image_url", sa.String(length=512), nullable=True),
        sa.Column("match_id", sa.String(length=128), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )
    op.create_index(
        "ix_player_mastery_change_log_user_id",
        "player_mastery_change_log",
        ["user_id"],
    )
    op.create_index(
        "ix_player_mastery_change_log_design_id",
        "player_mastery_change_log",
        ["design_id"],
    )
    op.create_index(
        "ix_player_mastery_change_log_match_id",
        "player_mastery_change_log",
        ["match_id"],
    )
    op.create_index(
        "ix_player_mastery_change_log_user_created",
        "player_mastery_change_log",
        ["user_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_player_mastery_change_log_user_created",
        table_name="player_mastery_change_log",
    )
    op.drop_index(
        "ix_player_mastery_change_log_match_id",
        table_name="player_mastery_change_log",
    )
    op.drop_index(
        "ix_player_mastery_change_log_design_id",
        table_name="player_mastery_change_log",
    )
    op.drop_index(
        "ix_player_mastery_change_log_user_id",
        table_name="player_mastery_change_log",
    )
    op.drop_table("player_mastery_change_log")
