"""Alembic migration — rewrite design id series token GEN00N → SER00N."""

from __future__ import annotations

from alembic import op


revision = "015_series_token_ser"
down_revision = "014_gold_arcori"
branch_labels = None
depends_on = None

# Longest-first replaces (GEN003 before GEN001).
_REPLACES = (
    ("GEN003", "SER003"),
    ("GEN002", "SER002"),
    ("GEN001", "SER001"),
)


def _sql_rewrite(column_expr: str) -> str:
    expr = column_expr
    for old, new in _REPLACES:
        expr = f"replace({expr}, '{old}', '{new}')"
    return expr


def upgrade() -> None:
    # String design-id columns
    for table, col in (
        ("player_design_access", "design_id"),
        ("player_mastery", "design_id"),
        ("player_slammers", "design_id"),
        ("player_trove", "design_id"),
        ("player_kin", "genesis_design_id"),
        ("design_standings", "internal_id"),
    ):
        rewritten = _sql_rewrite(col)
        op.execute(
            f"""
            UPDATE {table}
            SET {col} = {rewritten}
            WHERE {col} LIKE '%GEN00%'
            """
        )

    # Mirrored Kin design JSON may embed internalId / imageUrl / artworkPrompt.
    rewritten_json = _sql_rewrite("catalog_design::text")
    op.execute(
        f"""
        UPDATE player_kin
        SET catalog_design = ({rewritten_json})::jsonb
        WHERE catalog_design IS NOT NULL
          AND catalog_design::text LIKE '%GEN00%'
        """
    )


def downgrade() -> None:
    # Reverse SER → GEN (dev-only rollback).
    reverse = (
        ("SER003", "GEN003"),
        ("SER002", "GEN002"),
        ("SER001", "GEN001"),
    )

    def rev(expr: str) -> str:
        for old, new in reverse:
            expr = f"replace({expr}, '{old}', '{new}')"
        return expr

    for table, col in (
        ("player_design_access", "design_id"),
        ("player_mastery", "design_id"),
        ("player_slammers", "design_id"),
        ("player_trove", "design_id"),
        ("player_kin", "genesis_design_id"),
        ("design_standings", "internal_id"),
    ):
        rewritten = rev(col)
        op.execute(
            f"""
            UPDATE {table}
            SET {col} = {rewritten}
            WHERE {col} LIKE '%SER00%'
            """
        )

    rewritten_json = rev("catalog_design::text")
    op.execute(
        f"""
        UPDATE player_kin
        SET catalog_design = ({rewritten_json})::jsonb
        WHERE catalog_design IS NOT NULL
          AND catalog_design::text LIKE '%SER00%'
        """
    )
