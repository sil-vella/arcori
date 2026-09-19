"""Alembic migration — museum_generations list indexes."""

from __future__ import annotations

from alembic import op

revision = "025_museum_generations_indexes"
down_revision = "024_legacy_intent_items"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "ix_museum_generations_legacy_state",
        "museum_generations",
        ["legacy_state"],
        unique=False,
    )
    op.create_index(
        "ix_museum_generations_closed_at",
        "museum_generations",
        ["closed_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_museum_generations_closed_at", table_name="museum_generations")
    op.drop_index(
        "ix_museum_generations_legacy_state", table_name="museum_generations"
    )
