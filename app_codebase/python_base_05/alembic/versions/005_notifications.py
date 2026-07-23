"""Alembic migration — notifications tables + welcome global seed."""

from __future__ import annotations

import json
import uuid

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "005_notifications"
down_revision = "004_login_events"
branch_labels = None
depends_on = None

_WELCOME_GLOBAL_ID = uuid.UUID("65f0a1b2-c3d4-e5f6-0718-290200000001")


def upgrade() -> None:
    op.create_table(
        "user_notifications",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("source", sa.String(length=64), nullable=False),
        sa.Column("type", sa.String(length=16), nullable=False),
        sa.Column("subtype", sa.String(length=128), nullable=True),
        sa.Column("msg_id", sa.String(length=128), nullable=True),
        sa.Column("title", sa.String(length=512), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("data", postgresql.JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("responses", postgresql.JSONB(), nullable=False, server_default=sa.text("'[]'::jsonb")),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "type IN ('instant', 'inbox')",
            name="ck_user_notifications_type",
        ),
    )
    op.create_index("ix_user_notifications_user_id", "user_notifications", ["user_id"])
    op.create_index(
        "ix_user_notifications_user_created",
        "user_notifications",
        ["user_id", sa.text("created_at DESC")],
    )
    op.create_index(
        "ix_user_notifications_unread",
        "user_notifications",
        ["user_id"],
        postgresql_where=sa.text("read_at IS NULL AND deleted_at IS NULL"),
    )

    op.create_table(
        "global_notifications",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("source", sa.String(length=64), nullable=False, server_default="global_broadcast"),
        sa.Column("type", sa.String(length=16), nullable=False),
        sa.Column("subtype", sa.String(length=128), nullable=True),
        sa.Column("msg_id", sa.String(length=128), nullable=True),
        sa.Column("title", sa.String(length=512), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("data", postgresql.JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("responses", postgresql.JSONB(), nullable=False, server_default=sa.text("'[]'::jsonb")),
        sa.Column(
            "target_audience",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'{\"all\": true}'::jsonb"),
        ),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "type IN ('instant', 'inbox')",
            name="ck_global_notifications_type",
        ),
    )
    op.create_index(
        "ix_global_notifications_active",
        "global_notifications",
        ["is_active"],
    )

    op.create_table(
        "global_notification_reads",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "global_notification_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("global_notifications.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "read_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "user_id",
            "global_notification_id",
            name="uq_global_notification_reads_user_global",
        ),
    )
    op.create_index(
        "ix_global_notification_reads_user_id",
        "global_notification_reads",
        ["user_id"],
    )

    welcome_responses = json.dumps(
        [{"label": "Got it", "action_identifier": "dismiss"}]
    )
    op.execute(
        sa.text(
            """
            INSERT INTO global_notifications (
                id, source, type, subtype, msg_id, title, body,
                data, responses, target_audience, is_active
            ) VALUES (
                :id, 'global_broadcast', 'instant', 'welcome',
                'global_welcome_v1',
                'Welcome to Arcori',
                'You are in early — explore the example module and notifications inbox.',
                '{}'::jsonb,
                CAST(:responses AS jsonb),
                '{"all": true}'::jsonb,
                true
            )
            """
        ).bindparams(id=_WELCOME_GLOBAL_ID, responses=welcome_responses)
    )


def downgrade() -> None:
    op.drop_index("ix_global_notification_reads_user_id", table_name="global_notification_reads")
    op.drop_table("global_notification_reads")
    op.drop_index("ix_global_notifications_active", table_name="global_notifications")
    op.drop_table("global_notifications")
    op.drop_index("ix_user_notifications_unread", table_name="user_notifications")
    op.drop_index("ix_user_notifications_user_created", table_name="user_notifications")
    op.drop_index("ix_user_notifications_user_id", table_name="user_notifications")
    op.drop_table("user_notifications")
