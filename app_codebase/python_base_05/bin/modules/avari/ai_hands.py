"""Stable hand assignment for seeded AI players.

Two of every three AI users own one shop hand. The pick is a function of the
user id, so a re-run does not move a hand that was already written. The row
is ``player_hands`` with source ``ai``, the same table a bought hand uses.
"""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from core.utils.dev_logger import customlog
from models.avari_profile import AvariProfile
from models.user import User
from modules.avari import avari_repository as repo
from modules.catalog import catalog_repository as catalog_repo
from modules.market.market_skus import is_shop_hand
from modules.players.players_service import AI_EMAIL_DOMAIN, AI_SEED_MARKER

LOGGING_SWITCH = True

AI_HAND_SOURCE = "ai"


def stable_user_int(user_id: str) -> int:
    """128-bit mix of [user_id]. UUID form matches the Dart practice pick."""
    raw = (user_id or "").strip()
    if not raw:
        return 0
    try:
        return uuid.UUID(raw).int
    except ValueError:
        n = 0
        for ch in raw:
            n = (n * 131 + ord(ch)) & ((1 << 128) - 1)
        return n


def assigned_hand_id(user_id: str, hand_ids: list[str]) -> str | None:
    """One shop hand for two thirds of ids. None for the other third."""
    ids = [str(item).strip() for item in hand_ids if str(item).strip()]
    if not ids or not (user_id or "").strip():
        return None
    n = stable_user_int(user_id)
    if n % 3 == 0:
        return None
    return ids[(n // 3) % len(ids)]


def shop_hand_ids(session: Session) -> list[str]:
    """Catalog shop hands, lowest serial first. Same order the client list uses."""
    ids: list[str] = []
    for row in catalog_repo.list_by_theme_code(session, "HND"):
        iid = str(row.internal_id or "").strip()
        design = dict(row.design_json or {})
        if is_shop_hand(design, design_id=iid):
            ids.append(iid)

    def _serial(iid: str) -> tuple[int, str]:
        tail = iid.rsplit("-", 1)[-1]
        try:
            return (int(tail), iid)
        except ValueError:
            return (10**9, iid)

    ids.sort(key=_serial)
    return ids


def _ai_user_ids(session: Session) -> list[uuid.UUID]:
    stmt = (
        select(User.id)
        .join(AvariProfile, AvariProfile.user_id == User.id)
        .where(
            or_(
                AvariProfile.notes == AI_SEED_MARKER,
                func.lower(User.email).like(f"%{AI_EMAIL_DOMAIN}"),
            )
        )
    )
    return [row[0] for row in session.execute(stmt).all()]


def grant_hand_for_ai_user(session: Session, user_id: uuid.UUID) -> str:
    """Insert the stable hand when this AI owns none. Returns the design id or ''."""
    owned = repo.earliest_hand_design_id(session, user_id)
    if owned:
        return owned
    design_id = assigned_hand_id(str(user_id), shop_hand_ids(session))
    if not design_id:
        return ""
    repo.ensure_hand(
        session,
        user_id=user_id,
        design_id=design_id,
        source=AI_HAND_SOURCE,
    )
    if LOGGING_SWITCH:
        customlog(f"avari: ai hand grant user={user_id} design={design_id}")
    return design_id


def grant_ai_player_hands(session: Session) -> dict[str, int]:
    """Backfill ``player_hands`` for AI users. Skips anyone who already owns a hand."""
    ids = _ai_user_ids(session)
    granted = 0
    already = 0
    none = 0
    for user_id in ids:
        before = repo.earliest_hand_design_id(session, user_id)
        if before:
            already += 1
            continue
        design_id = grant_hand_for_ai_user(session, user_id)
        if design_id:
            granted += 1
        else:
            none += 1
    if LOGGING_SWITCH:
        customlog(
            f"avari: ai hand backfill ai={len(ids)} granted={granted} "
            f"already={already} none={none}"
        )
    return {
        "ai": len(ids),
        "granted": granted,
        "alreadyOwned": already,
        "none": none,
    }


def owned_hands_for_users(user_ids: list[str]) -> dict[str, Any]:
    """Earliest owned hand per user. Missing users are omitted."""
    from core.state.session_scope import session_scope

    hands: list[dict[str, str]] = []
    with session_scope() as session:
        for raw in user_ids:
            uid = str(raw or "").strip()
            if not uid:
                continue
            design_id = repo.earliest_hand_design_id(session, uid)
            if not design_id:
                continue
            hands.append({"userId": uid, "handId": design_id})
    if LOGGING_SWITCH:
        customlog(f"avari: owned hands count={len(hands)} asked={len(user_ids)}")
    return {"hands": hands}
