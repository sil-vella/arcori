"""First-session starter pack: 10 circulating Arcori + permanent slammer.

Pool: Genesis + Pioneers only (not Creation / Foundations).
Pick: 9 designs with selectionWeight in [8.0, 10.0], 1 with weight in [3.0, 4.0].
"""

from __future__ import annotations

import random
import uuid
from typing import Any

from sqlalchemy.orm import Session

from core.utils.dev_logger import customlog
from models.avari_profile import AvariProfile
from modules.avari.mastery_economy import STARTER_INITIAL_MASTERY
from modules.catalog import catalog_loader as loader

LOGGING_SWITCH = True

STARTER_PACK_SIZE = 10
STARTER_SLAMMER_ID = "SLM-STR-SER001-GEN001-0001"
# Starter unlocks only from launch companion catalogs — not Creation / Foundations+.
STARTER_SERIES_KEYS = frozenset({"genesis", "pioneers"})

# selectionWeight bands (inclusive): 9 common-ish + 1 scarcer.
STARTER_COMMON_WEIGHT_MIN = 8.0
STARTER_COMMON_WEIGHT_MAX = 10.0
STARTER_COMMON_COUNT = 9
STARTER_SCARCE_WEIGHT_MIN = 3.0
STARTER_SCARCE_WEIGHT_MAX = 4.0
STARTER_SCARCE_COUNT = 1


def _design_weight(design: dict[str, Any]) -> float | None:
    raw = design.get("selectionWeight")
    try:
        if raw is None:
            return None
        return float(raw)
    except (TypeError, ValueError):
        return None


def circulating_playable_designs() -> list[tuple[str, float]]:
    """Active Genesis/Pioneers Arcori (id, selectionWeight); excludes slammers / Kin."""
    out: list[tuple[str, float]] = []
    seen: set[str] = set()
    for doc in loader.list_theme_documents():
        series_key = str(doc.get("series") or "").strip().lower()
        if series_key not in STARTER_SERIES_KEYS:
            continue
        theme_code = str(doc.get("themeCode") or "").strip().upper()
        if theme_code in {"SLM", "KIN"}:
            continue
        designs = doc.get("designs")
        if not isinstance(designs, list):
            continue
        for design in designs:
            if not isinstance(design, dict):
                continue
            design_theme = str(design.get("themeCode") or theme_code).strip().upper()
            if design_theme in {"SLM", "KIN"}:
                continue
            dtype = str(design.get("type") or "").strip().lower()
            if dtype in {"slammer"}:
                continue
            world = str(design.get("worldState") or "").strip().lower()
            if world and world != "active":
                continue
            iid = str(design.get("internalId") or "").strip()
            if not iid or iid in seen:
                continue
            weight = _design_weight(design)
            if weight is None:
                continue
            seen.add(iid)
            out.append((iid, weight))
    return out


def circulating_playable_design_ids() -> list[str]:
    """Active Genesis/Pioneers Arcori ids (excludes slammers / Kin / other series)."""
    return [iid for iid, _ in circulating_playable_designs()]


def _in_band(weight: float, lo: float, hi: float) -> bool:
    return lo <= weight <= hi


def pick_starter_design_ids(
    count: int = STARTER_PACK_SIZE,
    *,
    rng: random.Random | None = None,
) -> list[str]:
    """9 from weight [8,10] + 1 from [3,4] within Genesis/Pioneers (when count=10)."""
    n = max(0, int(count))
    if n <= 0:
        return []
    picker = rng or random.Random()
    pool = circulating_playable_designs()
    if not pool:
        return []

    common = [
        iid
        for iid, w in pool
        if _in_band(w, STARTER_COMMON_WEIGHT_MIN, STARTER_COMMON_WEIGHT_MAX)
    ]
    scarce = [
        iid
        for iid, w in pool
        if _in_band(w, STARTER_SCARCE_WEIGHT_MIN, STARTER_SCARCE_WEIGHT_MAX)
    ]

    # Default pack shape only when asking for a full starter pack.
    if n == STARTER_PACK_SIZE:
        need_common = STARTER_COMMON_COUNT
        need_scarce = STARTER_SCARCE_COUNT
    else:
        # Tests / callers with other counts: proportional fill then remainder.
        need_scarce = min(1, n) if n >= STARTER_PACK_SIZE else 0
        need_common = n - need_scarce

    picked: list[str] = []
    taken: set[str] = set()

    def _take(candidates: list[str], want: int) -> None:
        available = [c for c in candidates if c not in taken]
        if not available or want <= 0:
            return
        k = min(want, len(available))
        chosen = picker.sample(available, k)
        picked.extend(chosen)
        taken.update(chosen)

    _take(scarce, need_scarce)
    _take(common, need_common)

    # Fallback: fill shortfall from the rest of the Gen/Pio pool.
    short = n - len(picked)
    if short > 0:
        rest = [iid for iid, _ in pool if iid not in taken]
        _take(rest, short)

    picker.shuffle(picked)
    return picked[:n]


def grant_starter_pack(
    session: Session,
    *,
    user_id: uuid.UUID,
    profile: AvariProfile,
    rng: random.Random | None = None,
) -> list[str]:
    """
    Idempotent: 10 banded circulating access + mastery STARTER_INITIAL_MASTERY
    each, plus permanent starter slammer. Sets onboarding_starter_granted.
    """
    from modules.avari import avari_repository as repo

    if bool(getattr(profile, "onboarding_starter_granted", False)):
        return []

    design_ids = pick_starter_design_ids(STARTER_PACK_SIZE, rng=rng)
    for design_id in design_ids:
        repo.ensure_design_access(
            session,
            user_id=user_id,
            design_id=design_id,
            source="starter",
        )
        repo.ensure_mastery_row(
            session,
            user_id=user_id,
            design_id=design_id,
            generation_number=1,
            initial_points=STARTER_INITIAL_MASTERY,
        )
        # Existing 0-point rows (rare race): bump to starter mastery.
        row = repo.ensure_mastery_row(
            session,
            user_id=user_id,
            design_id=design_id,
            generation_number=1,
        )
        if int(row.points) < STARTER_INITIAL_MASTERY:
            row.points = STARTER_INITIAL_MASTERY

    repo.ensure_slammer(
        session,
        user_id=user_id,
        design_id=STARTER_SLAMMER_ID,
        permanent=True,
        source="starter",
    )
    profile.onboarding_starter_granted = True
    session.flush()
    if LOGGING_SWITCH:
        customlog(
            f"avari: starter pack granted user={user_id} "
            f"designs={len(design_ids)} mastery={STARTER_INITIAL_MASTERY} "
            f"slammer={STARTER_SLAMMER_ID}"
        )
    return design_ids
