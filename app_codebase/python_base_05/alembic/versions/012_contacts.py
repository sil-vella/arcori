"""Alembic migration — user_contacts mutual contacts (two rows)."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision = "012_contacts"
down_revision = "011_player_profile"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_contacts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=False,
        ),
        sa.Column(
            "contact_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "user_id",
            "contact_user_id",
            name="uq_user_contacts_user_contact",
        ),
        sa.CheckConstraint(
            "user_id <> contact_user_id",
            name="ck_user_contacts_not_self",
        ),
    )
    op.create_index("ix_user_contacts_user_id", "user_contacts", ["user_id"])
    op.create_index(
        "ix_user_contacts_contact_user_id",
        "user_contacts",
        ["contact_user_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_user_contacts_contact_user_id", table_name="user_contacts")
    op.drop_index("ix_user_contacts_user_id", table_name="user_contacts")
    op.drop_table("user_contacts")

