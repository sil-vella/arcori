"""Alembic — verified Play and App Store fragment grants."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "034_store_fragment_purchases"
down_revision = "033_player_slammer_sweet_spot"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "store_fragment_purchases",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("platform", sa.String(length=16), nullable=False),
        sa.Column("product_id", sa.String(length=64), nullable=False),
        sa.Column("store_ref", sa.Text(), nullable=False),
        sa.Column("fragments_credited", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.String(length=128), nullable=True),
        sa.Column(
            "consume_ok",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "platform",
            "store_ref",
            name="uq_store_fragment_purchase_ref",
        ),
    )
    op.create_index(
        "ix_store_fragment_purchases_user_id",
        "store_fragment_purchases",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_store_fragment_purchases_user_id",
        table_name="store_fragment_purchases",
    )
    op.drop_table("store_fragment_purchases")
