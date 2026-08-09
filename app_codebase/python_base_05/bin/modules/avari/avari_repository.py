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


def find_player_kin(session: Session, user_id: str) -> PlayerKin | None:
    uid = _as_uuid(user_id)
    if uid is None:
        return None
    return session.scalars(select(PlayerKin).where(PlayerKin.user_id == uid)).first()


def list_design_access(session: Session, user_id: str) -> list[PlayerDesignAccess]:
    uid = _as_uuid(user_id)
    if uid is None:
        return []
    return list(
        session.scalars(
            select(PlayerDesignAccess).where(PlayerDesignAccess.user_id == uid)
        ).all()
    )


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
    return {
        "subtheme": row.subtheme,
        "style": row.style,
        "finish": row.finish,
        "effect": row.effect,
        "genesisDesignId": row.genesis_design_id,
        "chosenName": row.chosen_name,
        "customization": dict(row.customization or {}),
    }
