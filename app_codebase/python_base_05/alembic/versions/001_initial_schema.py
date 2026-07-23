"""Initial platform shell schema."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "001_initial_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "platform_meta",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "schema_version",
            sa.String(length=64),
            server_default="1",
            nullable=False,
        ),
    )
    op.execute("INSERT INTO platform_meta (schema_version) VALUES ('1')")


def downgrade() -> None:
    op.drop_table("platform_meta")
