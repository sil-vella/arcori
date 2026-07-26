"""Alembic migration — design_standings + design_standings_ranks."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "010_design_standings"
down_revision = "009_email_verified_at"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "design_standings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("internal_id", sa.String(length=64), nullable=False),
        sa.Column("generation_number", sa.Integer(), nullable=False),
        sa.Column("generation_roman", sa.String(length=16), nullable=True),
        sa.Column("fill_current", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("fill_cap", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("leader_window_ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "internal_id",
            "generation_number",
            name="uq_design_standings_internal_gen",
        ),
    )
    op.create_index(
        "ix_design_standings_internal_id",
        "design_standings",
        ["internal_id"],
    )

    op.create_table(
        "design_standings_ranks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("standing_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("rank", sa.Integer(), nullable=False),
        sa.Column("display_label", sa.String(length=128), nullable=False),
        sa.Column("mastery_points", sa.Integer(), nullable=False, server_default="0"),
        sa.ForeignKeyConstraint(
            ["standing_id"],
            ["design_standings.id"],
            ondelete="CASCADE",
        ),
    )
    op.create_index(
        "ix_design_standings_ranks_standing_id",
        "design_standings_ranks",
        ["standing_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_design_standings_ranks_standing_id",
        table_name="design_standings_ranks",
    )
    op.drop_table("design_standings_ranks")
    op.drop_index("ix_design_standings_internal_id", table_name="design_standings")
    op.drop_table("design_standings")
