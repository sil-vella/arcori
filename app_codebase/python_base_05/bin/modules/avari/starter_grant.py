"""First-session starter pack: 10 random circulating Arcori + permanent slammer."""

from __future__ import annotations

import random
import uuid

from sqlalchemy.orm import Session

from core.utils.dev_logger import customlog
from models.avari_profile import AvariProfile
from modules.avari.mastery_economy import STARTER_INITIAL_MASTERY
from modules.catalog import catalog_loader as loader

LOGGING_SWITCH = True

STARTER_PACK_SIZE = 10
STARTER_SLAMMER_ID = "SLM-STR-SER001-0001"
# Starter unlocks only from launch companion catalogs — not Creation / Foundations+.
STARTER_SERIES_KEYS = frozenset({"genesis", "pioneers"})


def circulating_playable_design_ids() -> list[str]:
    """Active Genesis/Pioneers Arcori ids (excludes slammers / Kin / other series)."""
    out: list[str] = []
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
            seen.add(iid)
            out.append(iid)
    return out


def pick_starter_design_ids(
    count: int = STARTER_PACK_SIZE,
    *,
    rng: random.Random | None = None,
) -> list[str]:
    """Random sample of circulating designs for a new player."""
    pool = circulating_playable_design_ids()
    n = max(0, int(count))
    if n <= 0 or not pool:
        return []
    picker = rng or random.Random()
    if len(pool) <= n:
        return list(pool)
    return picker.sample(pool, n)


def grant_starter_pack(
    session: Session,
    *,
    user_id: uuid.UUID,
    profile: AvariProfile,
    rng: random.Random | None = None,
) -> list[str]:
    """
    Idempotent: 10 random circulating access + mastery STARTER_INITIAL_MASTERY
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
