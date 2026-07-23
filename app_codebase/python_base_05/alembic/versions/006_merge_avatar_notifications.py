"""Merge 005_user_avatar_url and 005_notifications branches."""

from __future__ import annotations

revision = "006_merge_avatar_notifications"
down_revision = ("005_user_avatar_url", "005_notifications")
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
