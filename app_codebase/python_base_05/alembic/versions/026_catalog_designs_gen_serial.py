"""Alembic — catalog_designs table + inject GEN001 into design id strings."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "026_catalog_designs_gen_serial"
down_revision = "025_museum_generations_indexes"
branch_labels = None
depends_on = None

# Use standard SQL strings (not E''): in E-strings \1 becomes byte 0x01 and
# corrupts JSONB when casting text back. regexp_replace still treats \1 as a backref.
_REPL_TAIL = r"'-\1-GEN001-\2'"
_REPL_ANY = r"'-\1-GEN001-\2'"


def _table_exists(table: str) -> bool:
    bind = op.get_bind()
    row = bind.execute(
        sa.text(
            "SELECT 1 FROM information_schema.tables "
            "WHERE table_schema = 'public' AND table_name = :t"
        ),
        {"t": table},
    ).first()
    return row is not None


def _rewrite_col(table: str, col: str) -> None:
    if not _table_exists(table):
        return
    op.execute(
        f"""
        UPDATE {table}
        SET {col} = regexp_replace(
            {col},
            '-(SER[0-9]{{3}})-([0-9]+)$',
            {_REPL_TAIL}
        )
        WHERE {col} ~ '-(SER[0-9]{{3}})-[0-9]+$'
          AND {col} !~ '-GEN[0-9]{{3}}-'
        """
    )


def upgrade() -> None:
    if not _table_exists("catalog_designs"):
        op.create_table(
            "catalog_designs",
            sa.Column("internal_id", sa.String(length=96), primary_key=True),
            sa.Column("series_key", sa.String(length=64), nullable=False),
            sa.Column("theme", sa.String(length=64), nullable=False),
            sa.Column("theme_code", sa.String(length=16), nullable=False),
            sa.Column(
                "design_code",
                sa.String(length=32),
                nullable=False,
                server_default="",
            ),
            sa.Column("generation_number", sa.Integer(), nullable=False),
            sa.Column(
                "world_state",
                sa.String(length=16),
                nullable=False,
                server_default="Active",
            ),
            sa.Column(
                "design_json",
                postgresql.JSONB(astext_type=sa.Text()),
                nullable=False,
            ),
            sa.Column(
                "source",
                sa.String(length=16),
                nullable=False,
                server_default="seed",
            ),
            sa.Column("parent_internal_id", sa.String(length=96), nullable=True),
            sa.Column("catalog_version", sa.Integer(), nullable=True),
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
        )
        op.create_index(
            "ix_catalog_designs_series_key", "catalog_designs", ["series_key"]
        )
        op.create_index("ix_catalog_designs_theme", "catalog_designs", ["theme"])
        op.create_index(
            "ix_catalog_designs_theme_code", "catalog_designs", ["theme_code"]
        )
        op.create_index(
            "ix_catalog_designs_generation_number",
            "catalog_designs",
            ["generation_number"],
        )
        op.create_index(
            "ix_catalog_designs_world_state", "catalog_designs", ["world_state"]
        )

    for table, col in (
        ("player_design_access", "design_id"),
        ("player_mastery", "design_id"),
        ("player_slammers", "design_id"),
        ("player_trove", "design_id"),
        ("player_kin", "genesis_design_id"),
        ("design_standings", "internal_id"),
        ("design_generation_lifecycle", "design_id"),
        ("museum_generations", "design_id"),
        ("legacy_preserve_intent", "design_id"),
        ("legacy_fulfill_ledger", "design_id"),
    ):
        _rewrite_col(table, col)

    # JSONB: rewrite embedded internalIds without E'' escape corruption.
    if _table_exists("player_kin"):
        op.execute(
            f"""
            UPDATE player_kin
            SET catalog_design = (
                regexp_replace(
                    catalog_design::text,
                    '-(SER[0-9]{{3}})-([0-9]+)',
                    {_REPL_ANY},
                    'g'
                )
            )::jsonb
            WHERE catalog_design IS NOT NULL
              AND catalog_design::text ~ '-(SER[0-9]{{3}})-[0-9]+'
              AND catalog_design::text !~ '-GEN[0-9]{{3}}-'
            """
        )
    if _table_exists("legacy_preserve_intent"):
        op.execute(
            f"""
            UPDATE legacy_preserve_intent
            SET items_json = (
                regexp_replace(
                    items_json::text,
                    '-(SER[0-9]{{3}})-([0-9]+)',
                    {_REPL_ANY},
                    'g'
                )
            )::jsonb
            WHERE items_json IS NOT NULL
              AND items_json::text ~ '-(SER[0-9]{{3}})-[0-9]+'
              AND items_json::text !~ '-GEN[0-9]{{3}}-'
            """
        )


def downgrade() -> None:
    if not _table_exists("catalog_designs"):
        return
    op.drop_index("ix_catalog_designs_world_state", table_name="catalog_designs")
    op.drop_index(
        "ix_catalog_designs_generation_number", table_name="catalog_designs"
    )
    op.drop_index("ix_catalog_designs_theme_code", table_name="catalog_designs")
    op.drop_index("ix_catalog_designs_theme", table_name="catalog_designs")
    op.drop_index("ix_catalog_designs_series_key", table_name="catalog_designs")
    op.drop_table("catalog_designs")
