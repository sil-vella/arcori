"""Avari profile DB reads."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from models.avari_profile import AvariProfile
from models.player_progress import (
    MatchFeeLedger,
    MatchFinalizeLedger,
    PlayerClosedGeneration,
    PlayerDesignAccess,
    PlayerKin,
    PlayerMastery,
    PlayerSlammer,
    PlayerTrove,
)
from modules.avari.gold_economy import SIGNUP_GOLD_ARCORI


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
    from modules.avari.starter_grant import grant_starter_pack

    existing = session.scalars(
        select(AvariProfile).where(AvariProfile.user_id == user_id)
    ).first()
    if existing is not None:
        if not bool(existing.onboarding_starter_granted):
            grant_starter_pack(session, user_id=user_id, profile=existing)
        return existing

    name = (display_name or "Avari").strip()[:64] or "Avari"
    profile = AvariProfile(
        user_id=user_id,
        display_name=name,
        primary_title="Avari",
        titles=["Avari"],
        gold_arcori=SIGNUP_GOLD_ARCORI,
    )
    session.add(profile)
    session.flush()
    grant_starter_pack(session, user_id=user_id, profile=profile)
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


def revoke_design_access(
    session: Session,
    *,
    user_id: str | uuid.UUID,
    design_id: str,
) -> bool:
    """Remove circulating access for user+design. Returns True if a row was deleted."""
    uid = _as_uuid(user_id) if not isinstance(user_id, uuid.UUID) else user_id
    if uid is None:
        return False
    did = (design_id or "").strip()
    if not did:
        return False
    row = session.scalar(
        select(PlayerDesignAccess).where(
            PlayerDesignAccess.user_id == uid,
            PlayerDesignAccess.design_id == did,
        )
    )
    if row is None:
        return False
    session.delete(row)
    return True


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


def list_mastery_rows(session: Session, user_id: str) -> list[PlayerMastery]:
    uid = _as_uuid(user_id)
    if uid is None:
        return []
    return list(
        session.scalars(
            select(PlayerMastery).where(PlayerMastery.user_id == uid)
        ).all()
    )


def mastery_points_by_design(
    session: Session,
    user_id: str,
) -> dict[str, int]:
    """Best points per design_id (max across generations) for this player."""
    best: dict[str, int] = {}
    for row in list_mastery_rows(session, user_id):
        did = str(row.design_id or "").strip()
        if not did:
            continue
        pts = int(row.points)
        prev = best.get(did)
        if prev is None or pts > prev:
            best[did] = pts
    return best


def list_mastery_for_design_generation(
    session: Session,
    *,
    design_id: str,
    generation_number: int,
) -> list[PlayerMastery]:
    """All player_mastery rows for one design generation (any user)."""
    did = (design_id or "").strip()
    if not did:
        return []
    gen = max(1, int(generation_number))
    return list(
        session.scalars(
            select(PlayerMastery).where(
                PlayerMastery.design_id == did,
                PlayerMastery.generation_number == gen,
            )
        ).all()
    )


def ensure_mastery_row(
    session: Session,
    *,
    user_id: str | uuid.UUID,
    design_id: str,
    generation_number: int = 1,
    initial_points: int = 0,
    floor: int = 0,
) -> PlayerMastery:
    """Idempotent player_mastery row; optional initial points / floor."""
    from modules.avari.mastery_economy import clamp_points

    uid = _as_uuid(user_id) if not isinstance(user_id, uuid.UUID) else user_id
    if uid is None:
        raise ValueError("user_id required")
    did = (design_id or "").strip()
    if not did:
        raise ValueError("design_id required")
    gen = max(1, int(generation_number))
    floor_n = max(0, int(floor))
    initial = clamp_points(initial_points, floor=floor_n)
    existing = session.scalar(
        select(PlayerMastery).where(
            PlayerMastery.user_id == uid,
            PlayerMastery.design_id == did,
            PlayerMastery.generation_number == gen,
        )
    )
    if existing is not None:
        floored = clamp_points(int(existing.points), floor=floor_n)
        if floored != int(existing.points):
            existing.points = floored
            session.flush()
        return existing
    row = PlayerMastery(
        user_id=uid,
        design_id=did,
        generation_number=gen,
        points=initial,
    )
    session.add(row)
    session.flush()
    return row


def ensure_mastery_for_designs(
    session: Session,
    *,
    user_id: str | uuid.UUID,
    design_ids: list[str],
    generation_number: int = 1,
) -> None:
    """Ensure a player_mastery row exists for each circulating access design."""
    seen: set[str] = set()
    for raw in design_ids:
        did = str(raw or "").strip()
        if not did or did in seen:
            continue
        seen.add(did)
        ensure_mastery_row(
            session,
            user_id=user_id,
            design_id=did,
            generation_number=generation_number,
        )


def apply_mastery_delta(
    session: Session,
    *,
    user_id: str | uuid.UUID,
    design_id: str,
    delta: int,
    generation_number: int = 1,
    floor: int = 0,
) -> tuple[PlayerMastery, int, int]:
    """
    Apply delta to player_mastery, clamping at floor (default 0).

    Returns (row, points_before, points_after).
    """
    from modules.avari.mastery_economy import clamp_points

    row = ensure_mastery_row(
        session,
        user_id=user_id,
        design_id=design_id,
        generation_number=generation_number,
        floor=floor,
    )
    before = int(row.points)
    after = clamp_points(before + int(delta), floor=floor)
    row.points = after
    session.flush()
    return row, before, after


def count_mastery_designs(session: Session, user_id: str) -> int:
    uid = _as_uuid(user_id)
    if uid is None:
        return 0
    rows = session.scalars(
        select(PlayerMastery.design_id).where(PlayerMastery.user_id == uid).distinct()
    ).all()
    return len(rows)


def ensure_slammer(
    session: Session,
    *,
    user_id: str | uuid.UUID,
    design_id: str,
    permanent: bool = True,
    charges_remaining: int | None = None,
    source: str = "starter",
) -> PlayerSlammer:
    """Grant a slammer instance (idempotent on user+design)."""
    uid = _as_uuid(user_id) if not isinstance(user_id, uuid.UUID) else user_id
    if uid is None:
        raise ValueError("user_id required")
    did = (design_id or "").strip()
    if not did:
        raise ValueError("design_id required")
    existing = session.scalar(
        select(PlayerSlammer).where(
            PlayerSlammer.user_id == uid,
            PlayerSlammer.design_id == did,
        )
    )
    if existing is not None:
        if permanent and not bool(existing.permanent):
            existing.permanent = True
            existing.charges_remaining = None
            session.flush()
        return existing
    row = PlayerSlammer(
        user_id=uid,
        design_id=did[:64],
        permanent=bool(permanent),
        charges_remaining=None if permanent else charges_remaining,
        source=(source or "starter").strip()[:32] or "starter",
    )
    session.add(row)
    session.flush()
    return row


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


def list_closed_generations(
    session: Session, user_id: str
) -> list[PlayerClosedGeneration]:
    """Newest closed gens first (profile Past Generations section)."""
    uid = _as_uuid(user_id)
    if uid is None:
        return []
    return list(
        session.scalars(
            select(PlayerClosedGeneration)
            .where(PlayerClosedGeneration.user_id == uid)
            .order_by(
                PlayerClosedGeneration.closed_at.desc(),
                PlayerClosedGeneration.created_at.desc(),
            )
        ).all()
    )


def upsert_closed_generation(
    session: Session,
    *,
    user_id: str | uuid.UUID,
    design_id: str,
    generation_number: int,
    mastery_points: int,
    legacy_state: str,
    echo_design_id: str | None,
    echo_mastery_seeded: int = 0,
    echo_generation_number: int | None = None,
    closed_at: Any | None = None,
) -> PlayerClosedGeneration:
    """Idempotent mastery-at-closure snapshot for one player + design gen."""
    from datetime import datetime, timezone

    uid = _as_uuid(user_id) if not isinstance(user_id, uuid.UUID) else user_id
    if uid is None:
        raise ValueError("user_id required")
    did = (design_id or "").strip()
    if not did:
        raise ValueError("design_id required")
    gen = max(1, int(generation_number))
    pts = max(0, int(mastery_points))
    seeded = max(0, int(echo_mastery_seeded))
    echo_gen = (
        max(1, int(echo_generation_number))
        if echo_generation_number is not None
        else None
    )
    state = (legacy_state or "").strip().lower() or "lost"
    echo = (echo_design_id or "").strip() or None
    when = closed_at if closed_at is not None else datetime.now(timezone.utc)

    existing = session.scalar(
        select(PlayerClosedGeneration).where(
            PlayerClosedGeneration.user_id == uid,
            PlayerClosedGeneration.design_id == did,
            PlayerClosedGeneration.generation_number == gen,
        )
    )
    if existing is not None:
        existing.mastery_points = pts
        existing.echo_mastery_seeded = seeded
        existing.echo_generation_number = echo_gen
        existing.legacy_state = state
        existing.echo_design_id = echo
        existing.closed_at = when
        session.flush()
        return existing
    row = PlayerClosedGeneration(
        user_id=uid,
        design_id=did,
        generation_number=gen,
        mastery_points=pts,
        echo_mastery_seeded=seeded,
        echo_generation_number=echo_gen,
        legacy_state=state,
        echo_design_id=echo,
        closed_at=when,
    )
    session.add(row)
    session.flush()
    return row


def get_match_finalize(
    session: Session, user_id: str, match_id: str
) -> MatchFinalizeLedger | None:
    uid = _as_uuid(user_id)
    mid = (match_id or "").strip()
    if uid is None or not mid:
        return None
    return session.scalars(
        select(MatchFinalizeLedger).where(
            MatchFinalizeLedger.user_id == uid,
            MatchFinalizeLedger.match_id == mid,
        )
    ).first()


def insert_match_finalize(
    session: Session,
    *,
    user_id: str,
    match_id: str,
    response: dict[str, Any],
) -> MatchFinalizeLedger:
    uid = _as_uuid(user_id)
    mid = (match_id or "").strip()
    if uid is None:
        raise ValueError("invalid user_id")
    if not mid:
        raise ValueError("match_id required")
    row = MatchFinalizeLedger(
        user_id=uid,
        match_id=mid,
        response_json=dict(response),
    )
    session.add(row)
    session.flush()
    return row


FEE_KIND_PAY = "pay"
FEE_KIND_REFUND = "refund"


def get_match_fee(
    session: Session, user_id: str, intent_id: str, kind: str
) -> MatchFeeLedger | None:
    uid = _as_uuid(user_id)
    intent = (intent_id or "").strip()
    kind_value = (kind or "").strip()
    if uid is None or not intent or not kind_value:
        return None
    return session.scalars(
        select(MatchFeeLedger).where(
            MatchFeeLedger.user_id == uid,
            MatchFeeLedger.intent_id == intent,
            MatchFeeLedger.kind == kind_value,
        )
    ).first()


def insert_match_fee(
    session: Session,
    *,
    user_id: str,
    intent_id: str,
    kind: str,
    response: dict[str, Any],
) -> MatchFeeLedger:
    uid = _as_uuid(user_id)
    intent = (intent_id or "").strip()
    kind_value = (kind or "").strip()
    if uid is None:
        raise ValueError("invalid user_id")
    if not intent:
        raise ValueError("intent_id required")
    if not kind_value:
        raise ValueError("kind required")
    row = MatchFeeLedger(
        user_id=uid,
        intent_id=intent,
        kind=kind_value,
        response_json=dict(response),
    )
    session.add(row)
    session.flush()
    return row


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

