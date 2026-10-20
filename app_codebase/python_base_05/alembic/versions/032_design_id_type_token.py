"""Alembic — insert TYPE token into design ids (ARC/SLM; Kin unchanged).

``ANM-TIG-SER001-GEN001-0001`` → ``ARC-ANM-TIG-SER001-GEN001-0001``
``SLM-STR-SER001-GEN001-0001`` → ``SLM-SLM-STR-SER001-GEN001-0001``
``KIN-…`` left as-is (leading KIN is already the type).
"""

from __future__ import annotations

import re

import sqlalchemy as sa
from alembic import op

revision = "032_design_id_type_token"
down_revision = "031_unify_design_id_gen"
branch_labels = None
depends_on = None

_KIN = re.compile(r"^KIN-", re.IGNORECASE)
# Already typed: ARC-THEME-CODE-… or SLM-SLM-CODE-…
_TYPED = re.compile(r"^(ARC-[A-Z0-9]+-[A-Z0-9]+-|SLM-SLM-)", re.IGNORECASE)
_SLM_LEGACY = re.compile(
    r"^SLM-(?!SLM-)([A-Z0-9]+)-(SER\d{3})(?:-(GEN\d{3}))?-(\d+)$",
    re.IGNORECASE,
)
_ARC_LEGACY = re.compile(
    r"^(?!ARC-|SLM-|KIN-)([A-Z0-9]+)-([A-Z0-9]+)-(SER\d{3})(?:-(GEN\d{3}))?-(\d+)$",
    re.IGNORECASE,
)

_TABLES = (
    ("catalog_designs", "internal_id"),
    ("player_slammers", "design_id"),
    ("player_design_access", "design_id"),
    ("player_mastery", "design_id"),
    ("player_trove", "design_id"),
    ("player_closed_generations", "design_id"),
    ("museum_generations", "design_id"),
    ("player_mastery_change_log", "design_id"),
    ("match_finalize_ledger", "played_design_id"),
)


def _to_typed(design_id: str) -> str | None:
    raw = (design_id or "").strip()
    if not raw or _KIN.match(raw) or _TYPED.match(raw):
        return None
    m = _SLM_LEGACY.match(raw)
    if m:
        code, ser, gen, seq = m.group(1), m.group(2), m.group(3), m.group(4)
        gen_tok = (gen or "GEN001").upper()
        return f"SLM-SLM-{code.upper()}-{ser.upper()}-{gen_tok}-{seq}"
    m = _ARC_LEGACY.match(raw)
    if m is None:
        return None
    theme, code, ser, gen, seq = (
        m.group(1),
        m.group(2),
        m.group(3),
        m.group(4),
        m.group(5),
    )
    gen_tok = (gen or "GEN001").upper()
    return (
        f"ARC-{theme.upper()}-{code.upper()}-"
        f"{ser.upper()}-{gen_tok}-{seq}"
    )


def upgrade() -> None:
    conn = op.get_bind()
    for table, col in _TABLES:
        exists = conn.execute(
            sa.text(
                "SELECT 1 FROM information_schema.tables "
                "WHERE table_schema='public' AND table_name=:t"
            ),
            {"t": table},
        ).scalar()
        if not exists:
            continue
        col_exists = conn.execute(
            sa.text(
                "SELECT 1 FROM information_schema.columns "
                "WHERE table_schema='public' AND table_name=:t AND column_name=:c"
            ),
            {"t": table, "c": col},
        ).scalar()
        if not col_exists:
            continue

        rows = conn.execute(
            sa.text(f"SELECT {col} AS id FROM {table} WHERE {col} IS NOT NULL")
        ).mappings().all()
        # Unique map old → new; apply with collision-safe deletes for player tables.
        mapping: dict[str, str] = {}
        for row in rows:
            old = str(row["id"] or "").strip()
            new = _to_typed(old)
            if new and new != old:
                mapping[old] = new

        if not mapping:
            continue

        if table == "catalog_designs":
            for old, new in mapping.items():
                clash = conn.execute(
                    sa.text(
                        f"SELECT 1 FROM {table} WHERE {col} = :new"
                    ),
                    {"new": new},
                ).scalar()
                if clash:
                    conn.execute(
                        sa.text(f"DELETE FROM {table} WHERE {col} = :old"),
                        {"old": old},
                    )
                else:
                    conn.execute(
                        sa.text(
                            f"UPDATE {table} SET {col} = :new WHERE {col} = :old"
                        ),
                        {"new": new, "old": old},
                    )
            continue

        # Player-ish tables: may have (user_id, design_id) uniqueness.
        has_user = conn.execute(
            sa.text(
                "SELECT 1 FROM information_schema.columns "
                "WHERE table_schema='public' AND table_name=:t "
                "AND column_name='user_id'"
            ),
            {"t": table},
        ).scalar()

        if has_user and col == "design_id":
            for old, new in mapping.items():
                # Merge rows that would collide on (user_id, new).
                dupes = conn.execute(
                    sa.text(
                        f"""
                        SELECT a.id AS old_id, b.id AS new_id
                        FROM {table} a
                        JOIN {table} b
                          ON a.user_id = b.user_id
                         AND b.design_id = :new
                        WHERE a.design_id = :old
                        """
                    ),
                    {"old": old, "new": new},
                ).mappings().all()
                for d in dupes:
                    conn.execute(
                        sa.text(f"DELETE FROM {table} WHERE id = :id"),
                        {"id": d["old_id"]},
                    )
                conn.execute(
                    sa.text(
                        f"UPDATE {table} SET design_id = :new "
                        f"WHERE design_id = :old"
                    ),
                    {"new": new, "old": old},
                )
        else:
            for old, new in mapping.items():
                conn.execute(
                    sa.text(
                        f"UPDATE {table} SET {col} = :new WHERE {col} = :old"
                    ),
                    {"new": new, "old": old},
                )


def downgrade() -> None:
    # Irreversible — TYPE token removal would be ambiguous for SLM-SLM-*.
    pass
