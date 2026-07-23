"""Create ops_runtime table for drain_mode (shared across workers)."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "008_ops_runtime"
down_revision = "007_notification_category"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "ops_runtime",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "drain_mode",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.execute(
        "INSERT INTO ops_runtime (id, drain_mode) VALUES (1, false)"
    )


def downgrade() -> None:
    op.drop_table("ops_runtime")
