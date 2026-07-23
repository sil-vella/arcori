"""Add category column to notification tables."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "007_notification_category"
down_revision = "006_merge_avatar_notifications"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "user_notifications",
        sa.Column("category", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "global_notifications",
        sa.Column("category", sa.String(length=64), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("global_notifications", "category")
    op.drop_column("user_notifications", "category")
