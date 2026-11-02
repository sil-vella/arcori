"""Alembic — owned Market hands."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "035_player_hands"
down_revision = "034_store_fragment_purchases"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "player_hands",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("design_id", sa.String(length=64), nullable=False),
        sa.Column(
            "source",
            sa.String(length=32),
            nullable=False,
            server_default="market",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", "design_id", name="uq_player_hands_user_design"),
    )
    op.create_index("ix_player_hands_user_id", "player_hands", ["user_id"])
    op.create_index("ix_player_hands_design_id", "player_hands", ["design_id"])


def downgrade() -> None:
    op.drop_index("ix_player_hands_design_id", table_name="player_hands")
    op.drop_index("ix_player_hands_user_id", table_name="player_hands")
    op.drop_table("player_hands")
