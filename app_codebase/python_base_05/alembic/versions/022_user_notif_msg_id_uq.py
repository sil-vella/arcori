"""Alembic migration — unique user notification msg_id when set."""

from __future__ import annotations

from alembic import op

revision = "022_user_notif_msg_id_uq"
down_revision = "021_match_fee_ledger"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "uq_user_notifications_user_msg_id",
        "user_notifications",
        ["user_id", "msg_id"],
        unique=True,
        postgresql_where="msg_id IS NOT NULL",
    )


def downgrade() -> None:
    op.drop_index(
        "uq_user_notifications_user_msg_id",
        table_name="user_notifications",
    )
