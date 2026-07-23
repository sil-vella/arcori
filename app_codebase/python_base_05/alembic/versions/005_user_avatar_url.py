"""Alembic migration — users.avatar_url."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "005_user_avatar_url"
down_revision = "004_login_events"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("avatar_url", sa.String(length=512), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "avatar_url")
