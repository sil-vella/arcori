"""Alembic migration — legacy preserve lifecycle + fulfill + museum."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "023_legacy_preserve"
down_revision = "022_user_notif_msg_id_uq"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "design_generation_lifecycle",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("design_id", sa.String(length=64), nullable=False),
        sa.Column("generation_number", sa.Integer(), nullable=False),
        sa.Column(
            "phase",
            sa.String(length=32),
            nullable=False,
            server_default="racing",
        ),
        sa.Column("first_offer_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("first_offer_expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("leader_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("leader_since", sa.DateTime(timezone=True), nullable=True),
        sa.Column("leader_window_ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "preservation_requirement",
            sa.Integer(),
            nullable=False,
            server_default="500",
        ),
        sa.Column(
            "closure_milestone",
            sa.Integer(),
            nullable=False,
            server_default="1000",
        ),
        sa.Column("preserved_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "legacy_state",
            sa.String(length=16),
            nullable=False,
            server_default="none",
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["first_offer_user_id"], ["users.id"], ondelete="SET NULL"
        ),
        sa.ForeignKeyConstraint(["leader_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["preserved_user_id"], ["users.id"], ondelete="SET NULL"
        ),
        sa.UniqueConstraint(
            "design_id",
            "generation_number",
            name="uq_design_gen_lifecycle_design_gen",
        ),
    )
    op.create_index(
        "ix_design_generation_lifecycle_design_id",
        "design_generation_lifecycle",
        ["design_id"],
    )

    op.create_table(
        "legacy_preserve_intent",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("intent_id", sa.String(length=64), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("design_id", sa.String(length=64), nullable=False),
        sa.Column("generation_number", sa.Integer(), nullable=False),
        sa.Column(
            "checkout_status",
            sa.String(length=16),
            nullable=False,
            server_default="pending",
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("intent_id", name="uq_legacy_preserve_intent_intent_id"),
    )
    op.create_index(
        "ix_legacy_preserve_intent_intent_id",
        "legacy_preserve_intent",
        ["intent_id"],
    )
    op.create_index(
        "ix_legacy_preserve_intent_user_id",
        "legacy_preserve_intent",
        ["user_id"],
    )
    op.create_index(
        "ix_legacy_preserve_intent_design_id",
        "legacy_preserve_intent",
        ["design_id"],
    )

    op.create_table(
        "legacy_fulfill_ledger",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("order_id", sa.String(length=128), nullable=False),
        sa.Column("intent_id", sa.String(length=64), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("design_id", sa.String(length=64), nullable=False),
        sa.Column("generation_number", sa.Integer(), nullable=False),
        sa.Column(
            "response_json",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("order_id", name="uq_legacy_fulfill_ledger_order_id"),
    )
    op.create_index(
        "ix_legacy_fulfill_ledger_order_id",
        "legacy_fulfill_ledger",
        ["order_id"],
    )
    op.create_index(
        "ix_legacy_fulfill_ledger_intent_id",
        "legacy_fulfill_ledger",
        ["intent_id"],
    )
    op.create_index(
        "ix_legacy_fulfill_ledger_user_id",
        "legacy_fulfill_ledger",
        ["user_id"],
    )

    op.create_table(
        "museum_generations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("design_id", sa.String(length=64), nullable=False),
        sa.Column("generation_number", sa.Integer(), nullable=False),
        sa.Column("legacy_state", sa.String(length=16), nullable=False),
        sa.Column("preserved_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column(
            "closed_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "meta_json",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["preserved_user_id"], ["users.id"], ondelete="SET NULL"
        ),
        sa.UniqueConstraint(
            "design_id",
            "generation_number",
            name="uq_museum_generations_design_gen",
        ),
    )
    op.create_index(
        "ix_museum_generations_design_id",
        "museum_generations",
        ["design_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_museum_generations_design_id", table_name="museum_generations")
    op.drop_table("museum_generations")
    op.drop_index("ix_legacy_fulfill_ledger_user_id", table_name="legacy_fulfill_ledger")
    op.drop_index(
        "ix_legacy_fulfill_ledger_intent_id", table_name="legacy_fulfill_ledger"
    )
    op.drop_index("ix_legacy_fulfill_ledger_order_id", table_name="legacy_fulfill_ledger")
    op.drop_table("legacy_fulfill_ledger")
    op.drop_index("ix_legacy_preserve_intent_design_id", table_name="legacy_preserve_intent")
    op.drop_index("ix_legacy_preserve_intent_user_id", table_name="legacy_preserve_intent")
    op.drop_index(
        "ix_legacy_preserve_intent_intent_id", table_name="legacy_preserve_intent"
    )
    op.drop_table("legacy_preserve_intent")
    op.drop_index(
        "ix_design_generation_lifecycle_design_id",
        table_name="design_generation_lifecycle",
    )
    op.drop_table("design_generation_lifecycle")
