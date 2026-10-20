"""Alembic — merge short design ids into GENnnn form on player_slammers.

Catalog already stores THEME-CODE-SERnnn-GENnnn-####. Cutover left some
player_slammers rows on the legacy short form (no GEN). Merge stats into the
GEN row when both exist; otherwise rewrite short → GEN001.
"""

from __future__ import annotations

import re

import sqlalchemy as sa
from alembic import op

revision = "031_unify_design_id_gen"
down_revision = "030_slammer_mastery_legacy"
branch_labels = None
depends_on = None

_SHORT_RE = re.compile(
    r"^(?P<head>[A-Z0-9]+-[A-Z0-9]+-SER\d{3})-(?P<seq>\d+)$",
    re.IGNORECASE,
)


def _to_gen001(design_id: str) -> str | None:
    raw = (design_id or "").strip()
    if not raw or "-GEN" in raw.upper():
        return None
    m = _SHORT_RE.match(raw)
    if m is None:
        return None
    return f"{m.group('head').upper()}-GEN001-{m.group('seq')}"


def upgrade() -> None:
    conn = op.get_bind()
    rows = conn.execute(
        sa.text(
            "SELECT id, user_id, design_id, permanent, charges_remaining, "
            "source, mastery_points, matches_count, successful_slams, "
            "arcori_flipped, best_slam, legacy_id, legacy_snapshot "
            "FROM player_slammers"
        )
    ).mappings().all()

    by_user: dict[str, list] = {}
    for row in rows:
        by_user.setdefault(str(row["user_id"]), []).append(dict(row))

    for user_rows in by_user.values():
        by_id = {r["design_id"]: r for r in user_rows}
        short_rows = [r for r in user_rows if _to_gen001(r["design_id"])]
        for short in short_rows:
            gen_id = _to_gen001(short["design_id"])
            if not gen_id:
                continue
            target = by_id.get(gen_id)
            if target is None:
                conn.execute(
                    sa.text(
                        "UPDATE player_slammers SET design_id = :gen "
                        "WHERE id = :id"
                    ),
                    {"gen": gen_id[:64], "id": short["id"]},
                )
                by_id[gen_id] = {**short, "design_id": gen_id}
                by_id.pop(short["design_id"], None)
                continue

            permanent = bool(target["permanent"]) or bool(short["permanent"])
            charges = None if permanent else (
                target["charges_remaining"]
                if target["charges_remaining"] is not None
                else short["charges_remaining"]
            )
            if (
                not permanent
                and target["charges_remaining"] is not None
                and short["charges_remaining"] is not None
            ):
                charges = max(
                    int(target["charges_remaining"]),
                    int(short["charges_remaining"]),
                )
            source = target["source"]
            if source == "mastery" and short["source"] == "starter":
                source = "starter"
            mastery = float(target["mastery_points"] or 0) + float(
                short["mastery_points"] or 0
            )
            matches = int(target["matches_count"] or 0) + int(
                short["matches_count"] or 0
            )
            slams = int(target["successful_slams"] or 0) + int(
                short["successful_slams"] or 0
            )
            flips = int(target["arcori_flipped"] or 0) + int(
                short["arcori_flipped"] or 0
            )
            best = max(int(target["best_slam"] or 0), int(short["best_slam"] or 0))
            legacy_id = target["legacy_id"] or short["legacy_id"]
            legacy_snap = target["legacy_snapshot"] or short["legacy_snapshot"]

            conn.execute(
                sa.text(
                    "UPDATE player_slammers SET "
                    "permanent = :permanent, "
                    "charges_remaining = :charges, "
                    "source = :source, "
                    "mastery_points = :mastery, "
                    "matches_count = :matches, "
                    "successful_slams = :slams, "
                    "arcori_flipped = :flips, "
                    "best_slam = :best, "
                    "legacy_id = :legacy_id, "
                    "legacy_snapshot = :legacy_snap "
                    "WHERE id = :id"
                ),
                {
                    "permanent": permanent,
                    "charges": charges,
                    "source": source,
                    "mastery": mastery,
                    "matches": matches,
                    "slams": slams,
                    "flips": flips,
                    "best": best,
                    "legacy_id": legacy_id,
                    "legacy_snap": legacy_snap,
                    "id": target["id"],
                },
            )
            conn.execute(
                sa.text("DELETE FROM player_slammers WHERE id = :id"),
                {"id": short["id"]},
            )
            by_id.pop(short["design_id"], None)


def downgrade() -> None:
    # Irreversible merge — short duplicates are not restored.
    pass
