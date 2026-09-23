"""Legacy preserve DB access."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from models.legacy_preserve import (
    INTENT_FULFILLED,
    INTENT_PENDING,
    DesignGenerationLifecycle,
    LegacyFulfillLedger,
    LegacyPreserveIntent,
    MuseumGeneration,
    PHASE_FIRST_OFFER,
    PHASE_LEADER_WINDOW,
    PHASE_RACING,
)
from models.player_progress import PlayerMastery, PlayerTrove


def _as_uuid(user_id: str) -> uuid.UUID | None:
    try:
        return uuid.UUID(user_id)
    except ValueError:
        return None


def get_lifecycle(
    session: Session, design_id: str, generation_number: int
) -> DesignGenerationLifecycle | None:
    did = (design_id or "").strip()
    if not did:
        return None
    return session.scalars(
        select(DesignGenerationLifecycle).where(
            DesignGenerationLifecycle.design_id == did,
            DesignGenerationLifecycle.generation_number == int(generation_number),
        )
    ).first()


def ensure_lifecycle(
    session: Session,
    *,
    design_id: str,
    generation_number: int,
    preservation_requirement: int,
    closure_milestone: int,
) -> DesignGenerationLifecycle:
    existing = get_lifecycle(session, design_id, generation_number)
    if existing is not None:
        return existing
    row = DesignGenerationLifecycle(
        design_id=design_id.strip(),
        generation_number=int(generation_number),
        phase=PHASE_RACING,
        preservation_requirement=int(preservation_requirement),
        closure_milestone=int(closure_milestone),
    )
    session.add(row)
    session.flush()
    return row


def get_mastery_points(
    session: Session, user_id: str, design_id: str, generation_number: int
) -> int:
    uid = _as_uuid(user_id)
    did = (design_id or "").strip()
    if uid is None or not did:
        return 0
    row = session.scalars(
        select(PlayerMastery).where(
            PlayerMastery.user_id == uid,
            PlayerMastery.design_id == did,
            PlayerMastery.generation_number == int(generation_number),
        )
    ).first()
    if row is None:
        return 0
    try:
        return int(row.points or 0)
    except (TypeError, ValueError):
        return 0


def get_intent(session: Session, intent_id: str) -> LegacyPreserveIntent | None:
    iid = (intent_id or "").strip()
    if not iid:
        return None
    return session.scalars(
        select(LegacyPreserveIntent).where(LegacyPreserveIntent.intent_id == iid)
    ).first()


def insert_intent(
    session: Session,
    *,
    intent_id: str,
    user_id: str,
    design_id: str,
    generation_number: int,
    expires_at: datetime | None,
    items: list[dict[str, Any]] | None = None,
) -> LegacyPreserveIntent:
    uid = _as_uuid(user_id)
    if uid is None:
        raise ValueError("invalid user_id")
    row = LegacyPreserveIntent(
        intent_id=intent_id.strip(),
        user_id=uid,
        design_id=design_id.strip(),
        generation_number=int(generation_number),
        items_json=list(items) if items else None,
        checkout_status=INTENT_PENDING,
        expires_at=expires_at,
    )
    session.add(row)
    session.flush()
    return row


def get_fulfill(session: Session, order_id: str) -> LegacyFulfillLedger | None:
    oid = (order_id or "").strip()
    if not oid:
        return None
    return session.scalars(
        select(LegacyFulfillLedger).where(LegacyFulfillLedger.order_id == oid)
    ).first()


def get_fulfill_by_intent(
    session: Session, intent_id: str
) -> LegacyFulfillLedger | None:
    iid = (intent_id or "").strip()
    if not iid:
        return None
    return session.scalars(
        select(LegacyFulfillLedger)
        .where(LegacyFulfillLedger.intent_id == iid)
        .order_by(LegacyFulfillLedger.created_at.desc())
    ).first()


def insert_fulfill(
    session: Session,
    *,
    order_id: str,
    intent_id: str,
    user_id: str,
    design_id: str,
    generation_number: int,
    response: dict[str, Any],
) -> LegacyFulfillLedger:
    uid = _as_uuid(user_id)
    if uid is None:
        raise ValueError("invalid user_id")
    row = LegacyFulfillLedger(
        order_id=order_id.strip(),
        intent_id=intent_id.strip(),
        user_id=uid,
        design_id=design_id.strip(),
        generation_number=int(generation_number),
        response_json=dict(response),
    )
    session.add(row)
    session.flush()
    return row


def mark_intent_fulfilled(session: Session, intent: LegacyPreserveIntent) -> None:
    intent.checkout_status = INTENT_FULFILLED
    session.flush()


def insert_trove_mint(
    session: Session,
    *,
    user_id: str,
    design_id: str,
    generation_number: int,
    creator_attributed: bool,
) -> PlayerTrove:
    uid = _as_uuid(user_id)
    if uid is None:
        raise ValueError("invalid user_id")
    row = PlayerTrove(
        user_id=uid,
        design_id=design_id.strip(),
        generation_number=int(generation_number),
        legacy_title="Legacy Owner",
        creator_attributed=bool(creator_attributed),
    )
    session.add(row)
    session.flush()
    return row


def insert_museum(
    session: Session,
    *,
    design_id: str,
    generation_number: int,
    legacy_state: str,
    preserved_user_id: str | None,
    meta: dict[str, Any] | None = None,
) -> MuseumGeneration:
    puid = _as_uuid(preserved_user_id) if preserved_user_id else None
    row = MuseumGeneration(
        design_id=design_id.strip(),
        generation_number=int(generation_number),
        legacy_state=legacy_state,
        preserved_user_id=puid,
        meta_json=dict(meta or {}),
    )
    session.add(row)
    session.flush()
    return row


def get_museum_generation(
    session: Session,
    *,
    design_id: str,
    generation_number: int,
) -> MuseumGeneration | None:
    did = (design_id or "").strip()
    if not did:
        return None
    return session.scalars(
        select(MuseumGeneration).where(
            MuseumGeneration.design_id == did,
            MuseumGeneration.generation_number == int(generation_number),
        )
    ).first()


def get_latest_museum_generation_for_design(
    session: Session,
    *,
    design_id: str,
) -> MuseumGeneration | None:
    """Newest closed museum row for an exact design_id (serial)."""
    did = (design_id or "").strip()
    if not did:
        return None
    return session.scalars(
        select(MuseumGeneration)
        .where(MuseumGeneration.design_id == did)
        .order_by(
            MuseumGeneration.closed_at.desc(),
            MuseumGeneration.id.desc(),
        )
        .limit(1)
    ).first()


def list_museum_generations(
    session: Session,
    *,
    legacy_state: str | None = None,
    design_id_contains: str | None = None,
    limit: int = 30,
    cursor_closed_at: datetime | None = None,
    cursor_id: uuid.UUID | None = None,
) -> list[MuseumGeneration]:
    """Newest closed generations first. Optional outcome + design_id substring."""
    lim = max(1, min(100, int(limit)))
    stmt = select(MuseumGeneration)
    state = (legacy_state or "").strip().lower()
    if state in ("preserved", "lost"):
        stmt = stmt.where(MuseumGeneration.legacy_state == state)
    needle = (design_id_contains or "").strip()
    if needle:
        stmt = stmt.where(MuseumGeneration.design_id.ilike(f"%{needle}%"))
    if cursor_closed_at is not None and cursor_id is not None:
        stmt = stmt.where(
            (MuseumGeneration.closed_at < cursor_closed_at)
            | (
                (MuseumGeneration.closed_at == cursor_closed_at)
                & (MuseumGeneration.id < cursor_id)
            )
        )
    stmt = stmt.order_by(
        MuseumGeneration.closed_at.desc(),
        MuseumGeneration.id.desc(),
    ).limit(lim)
    return list(session.scalars(stmt).all())


def museum_has_series_token(
    session: Session,
    *,
    series_token: str,
    legacy_state: str | None = None,
) -> bool:
    """True if any closed museum row matches the series id token (e.g. SER001)."""
    token = (series_token or "").strip()
    if not token:
        return False
    stmt = select(MuseumGeneration.id).where(
        MuseumGeneration.design_id.ilike(f"%{token}%")
    )
    state = (legacy_state or "").strip().lower()
    if state in ("preserved", "lost"):
        stmt = stmt.where(MuseumGeneration.legacy_state == state)
    return session.scalars(stmt.limit(1)).first() is not None


def list_open_first_offers(session: Session) -> list[DesignGenerationLifecycle]:
    now = datetime.now(timezone.utc)
    return list(
        session.scalars(
            select(DesignGenerationLifecycle).where(
                DesignGenerationLifecycle.phase == PHASE_FIRST_OFFER,
                DesignGenerationLifecycle.first_offer_expires_at.is_not(None),
                DesignGenerationLifecycle.first_offer_expires_at <= now,
            )
        ).all()
    )


def list_open_preservation_windows(
    session: Session,
) -> list[DesignGenerationLifecycle]:
    """Active first_offer / leader_window rows (still racing toward Lost or mint)."""
    return list(
        session.scalars(
            select(DesignGenerationLifecycle)
            .where(
                DesignGenerationLifecycle.phase.in_(
                    (PHASE_FIRST_OFFER, PHASE_LEADER_WINDOW)
                )
            )
            .order_by(DesignGenerationLifecycle.design_id.asc())
        ).all()
    )


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def days_from_now(days: int) -> datetime:
    return utcnow() + timedelta(days=days)


def minutes_from_now(minutes: int) -> datetime:
    return utcnow() + timedelta(minutes=minutes)
