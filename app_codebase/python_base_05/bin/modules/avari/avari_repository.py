"""Avari profile DB reads."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from models.avari_profile import AvariProfile
from models.player_progress import (
    PlayerDesignAccess,
    PlayerKin,
    PlayerMastery,
    PlayerSlammer,
    PlayerTrove,
)


def _as_uuid(user_id: str) -> uuid.UUID | None:
    try:
        return uuid.UUID(user_id)
    except ValueError:
        return None


def find_avari_profile(session: Session, user_id: str) -> AvariProfile | None:
    uid = _as_uuid(user_id)
    if uid is None:
        return None
    return session.scalars(
        select(AvariProfile).where(AvariProfile.user_id == uid)
    ).first()


def ensure_avari_profile(
    session: Session,
    *,
    user_id: uuid.UUID,
    display_name: str,
) -> AvariProfile:
    """Create a starter Avari profile row when the auth account has none yet."""
    existing = session.scalars(
        select(AvariProfile).where(AvariProfile.user_id == user_id)
    ).first()
    if existing is not None:
        return existing

    name = (display_name or "Avari").strip()[:64] or "Avari"
    profile = AvariProfile(
        user_id=user_id,
        display_name=name,
        primary_title="Avari",
        titles=["Avari"],
    )
    session.add(profile)
    session.flush()
    return profile


def find_player_kin(session: Session, user_id: str) -> PlayerKin | None:
    uid = _as_uuid(user_id)
    if uid is None:
        return None
    return session.scalars(select(PlayerKin).where(PlayerKin.user_id == uid)).first()


def find_player_kin_by_design_id(
    session: Session, genesis_design_id: str
) -> PlayerKin | None:
    design_id = (genesis_design_id or "").strip()
    if not design_id:
        return None
    return session.scalars(
        select(PlayerKin).where(PlayerKin.genesis_design_id == design_id)
    ).first()


def count_player_kin(session: Session) -> int:
    from sqlalchemy import func

    return int(session.scalar(select(func.count()).select_from(PlayerKin)) or 0)


def list_design_access(session: Session, user_id: str) -> list[PlayerDesignAccess]:
    uid = _as_uuid(user_id)
    if uid is None:
        return []
    return list(
        session.scalars(
            select(PlayerDesignAccess).where(PlayerDesignAccess.user_id == uid)
        ).all()
    )


def ensure_design_access(
    session: Session,
    *,
    user_id: str | uuid.UUID,
    design_id: str,
    source: str = "kin",
) -> PlayerDesignAccess:
    """Grant circulating play/mastery access (idempotent on user+design)."""
    uid = _as_uuid(user_id) if not isinstance(user_id, uuid.UUID) else user_id
    if uid is None:
        raise ValueError("user_id required")
    did = (design_id or "").strip()
    if not did:
        raise ValueError("design_id required")
    existing = session.scalar(
        select(PlayerDesignAccess).where(
            PlayerDesignAccess.user_id == uid,
            PlayerDesignAccess.design_id == did,
        )
    )
    if existing is not None:
        return existing
    row = PlayerDesignAccess(
        user_id=uid,
        design_id=did,
        source=(source or "kin").strip()[:32] or "kin",
    )
    session.add(row)
    return row


def list_mastery_top(
    session: Session,
    user_id: str,
    *,
    limit: int = 5,
) -> list[PlayerMastery]:
    uid = _as_uuid(user_id)
    if uid is None:
        return []
    stmt = (
        select(PlayerMastery)
        .where(PlayerMastery.user_id == uid)
        .order_by(PlayerMastery.points.desc())
        .limit(limit)
    )
    return list(session.scalars(stmt).all())


def count_mastery_designs(session: Session, user_id: str) -> int:
    uid = _as_uuid(user_id)
    if uid is None:
        return 0
    rows = session.scalars(
        select(PlayerMastery.design_id).where(PlayerMastery.user_id == uid).distinct()
    ).all()
    return len(rows)


def list_slammers(session: Session, user_id: str) -> list[PlayerSlammer]:
    uid = _as_uuid(user_id)
    if uid is None:
        return []
    return list(
        session.scalars(select(PlayerSlammer).where(PlayerSlammer.user_id == uid)).all()
    )


def list_trove(session: Session, user_id: str) -> list[PlayerTrove]:
    uid = _as_uuid(user_id)
    if uid is None:
        return []
    return list(
        session.scalars(select(PlayerTrove).where(PlayerTrove.user_id == uid)).all()
    )


def serialize_kin(row: PlayerKin | None) -> dict[str, Any] | None:
    if row is None:
        return None
    raw_design = getattr(row, "catalog_design", None)
    design = dict(raw_design) if isinstance(raw_design, dict) else {}
    location = design.get("location") if isinstance(design.get("location"), dict) else {}
    generation = (
        design.get("generation") if isinstance(design.get("generation"), dict) else {}
    )
    from modules.avari.kin_genesis import lottie_public_url

    out: dict[str, Any] = {
        "subtheme": row.subtheme,
        "style": row.style,
        "finish": row.finish,
        "effect": row.effect,
        "genesisDesignId": row.genesis_design_id,
        "chosenName": row.chosen_name,
        "customization": dict(row.customization or {}),
    }
    if design:
        out["catalogDesign"] = design
        out["color"] = design.get("color")
        out["series"] = design.get("series")
        out["regionCode"] = location.get("regionCode")
        out["generation"] = {
            "roman": generation.get("roman"),
            "number": generation.get("number"),
        }
        out["lottieUrl"] = lottie_public_url(row.genesis_design_id)
    return out

