"""Alembic — closed-gen snapshot: echo mastery seed amount + echo gen number."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "028_closed_gen_echo_seed"
down_revision = "027_player_closed_generations"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "player_closed_generations",
        sa.Column(
            "echo_mastery_seeded",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "player_closed_generations",
        sa.Column("echo_generation_number", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("player_closed_generations", "echo_generation_number")
    op.drop_column("player_closed_generations", "echo_mastery_seeded")
