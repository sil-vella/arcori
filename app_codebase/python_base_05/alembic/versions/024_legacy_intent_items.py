"""Alembic migration — legacy preserve intent batch items_json."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "024_legacy_intent_items"
down_revision = "023_legacy_preserve"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "legacy_preserve_intent",
        sa.Column("items_json", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("legacy_preserve_intent", "items_json")
