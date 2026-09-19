"""Alembic — player_closed_generations (mastery snapshot at Legacy close)."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "027_player_closed_generations"
down_revision = "026_catalog_designs_gen_serial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "player_closed_generations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("design_id", sa.String(length=64), nullable=False),
        sa.Column("generation_number", sa.Integer(), nullable=False),
        sa.Column(
            "mastery_points",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column("legacy_state", sa.String(length=32), nullable=False),
        sa.Column("echo_design_id", sa.String(length=64), nullable=True),
        sa.Column(
            "closed_at",
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
            "design_id",
            "generation_number",
            name="uq_player_closed_generations_user_design_gen",
        ),
    )
    op.create_index(
        "ix_player_closed_generations_user_id",
        "player_closed_generations",
        ["user_id"],
    )
    op.create_index(
        "ix_player_closed_generations_design_id",
        "player_closed_generations",
        ["design_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_player_closed_generations_design_id",
        table_name="player_closed_generations",
    )
    op.drop_index(
        "ix_player_closed_generations_user_id",
        table_name="player_closed_generations",
    )
    op.drop_table("player_closed_generations")
