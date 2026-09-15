"""Player special-event progress (flips, designs, match credit)."""

from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from models.player_progress import PlayerSpecialEventProgress


def _as_uuid(user_id: str) -> uuid.UUID | None:
    try:
        return uuid.UUID(user_id)
    except ValueError:
        return None


def _normalize_ids(raw: Any) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    if not isinstance(raw, list):
        return out
    for item in raw:
        did = str(item or "").strip()
        if not did or did in seen:
            continue
        seen.add(did)
        out.append(did)
    return out


def get_progress_row(
    session: Session, *, user_id: str, event_id: str
) -> PlayerSpecialEventProgress | None:
    uid = _as_uuid(user_id)
    eid = (event_id or "").strip()
    if uid is None or not eid:
        return None
    return session.scalar(
        select(PlayerSpecialEventProgress).where(
            PlayerSpecialEventProgress.user_id == uid,
            PlayerSpecialEventProgress.event_id == eid,
        )
    )


def upsert_progress_row(
    session: Session, *, user_id: str, event_id: str
) -> PlayerSpecialEventProgress | None:
    uid = _as_uuid(user_id)
    eid = (event_id or "").strip()
    if uid is None or not eid:
        return None
    row = get_progress_row(session, user_id=user_id, event_id=eid)
    if row is not None:
        return row
    row = PlayerSpecialEventProgress(
        id=uuid.uuid4(),
        user_id=uid,
        event_id=eid,
        flips=0,
        flipped_design_ids=[],
        matches_completed=0,
        matches_won=0,
        matches_credited=0,
        last_match_id=None,
    )
    session.add(row)
    session.flush()
    return row


def apply_match_progress(
    session: Session,
    *,
    user_id: str,
    event_id: str,
    flips: int,
    flipped_design_ids: list[str],
    won: bool = False,
    match_id: str | None = None,
    credit: bool = False,
) -> dict[str, Any]:
    """
    Accumulate event flips, unique design ids, and optional match credit.

    Returns progress snapshot for finalize / client.
    """
    row = upsert_progress_row(session, user_id=user_id, event_id=event_id)
    if row is None:
        return progress_snapshot(session, user_id=user_id, event_id=event_id)

    mid = (match_id or "").strip()
    # Idempotent: same matchId does not double-count.
    if mid and str(row.last_match_id or "") == mid:
        return _row_snapshot(row)

    add_flips = max(0, int(flips))
    row.flips = int(row.flips or 0) + add_flips
    merged = _normalize_ids(row.flipped_design_ids)
    seen = set(merged)
    for did in flipped_design_ids:
        key = str(did or "").strip()
        if not key or key in seen:
            continue
        seen.add(key)
        merged.append(key)
    row.flipped_design_ids = merged

    row.matches_completed = int(row.matches_completed or 0) + 1
    if won:
        row.matches_won = int(row.matches_won or 0) + 1
    if credit:
        row.matches_credited = int(row.matches_credited or 0) + 1
    if mid:
        row.last_match_id = mid

    session.flush()
    return _row_snapshot(row)


def _row_snapshot(row: PlayerSpecialEventProgress) -> dict[str, Any]:
    return {
        "eventId": row.event_id,
        "flips": int(row.flips or 0),
        "flippedDesignIds": _normalize_ids(row.flipped_design_ids),
        "matchesCompleted": int(row.matches_completed or 0),
        "matchesWon": int(row.matches_won or 0),
        "matchesCredited": int(row.matches_credited or 0),
        "lastMatchId": row.last_match_id,
    }


def progress_snapshot(
    session: Session, *, user_id: str, event_id: str
) -> dict[str, Any]:
    row = get_progress_row(session, user_id=user_id, event_id=event_id)
    if row is None:
        return {
            "eventId": (event_id or "").strip(),
            "flips": 0,
            "flippedDesignIds": [],
            "matchesCompleted": 0,
            "matchesWon": 0,
            "matchesCredited": 0,
            "lastMatchId": None,
        }
    return _row_snapshot(row)
