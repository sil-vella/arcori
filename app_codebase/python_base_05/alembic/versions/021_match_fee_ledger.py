"""Alembic migration — match fee pay/refund idempotency ledger."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "021_match_fee_ledger"
down_revision = "020_match_finalize_ledger"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "match_fee_ledger",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("intent_id", sa.String(length=64), nullable=False),
        sa.Column("kind", sa.String(length=16), nullable=False),
        sa.Column("response_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "user_id",
            "intent_id",
            "kind",
            name="uq_match_fee_ledger_user_intent_kind",
        ),
    )
    op.create_index(
        "ix_match_fee_ledger_user_id",
        "match_fee_ledger",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_match_fee_ledger_user_id", table_name="match_fee_ledger")
    op.drop_table("match_fee_ledger")
