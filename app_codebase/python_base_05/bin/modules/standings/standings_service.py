"""Standings business logic — read + internal replace/clear (no public writes)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from core.errors.app_error import AppError
from core.state.session_scope import session_scope
from modules.catalog.catalog_errors import NOT_FOUND as CATALOG_NOT_FOUND
from modules.catalog.catalog_service import get_design
from modules.standings import standings_repository as repo
from modules.standings.standings_errors import INVALID_QUERY


def _generation_from_design(design: dict[str, Any]) -> tuple[int, str | None]:
    gen = design.get("generation")
    if not isinstance(gen, dict):
        return 1, None
    number = gen.get("number")
    try:
        gen_num = int(number) if number is not None else 1
    except (TypeError, ValueError):
        gen_num = 1
    roman = gen.get("roman")
    roman_s = str(roman).strip() if roman is not None else None
    return gen_num, roman_s or None


def _empty_payload(
    *,
    internal_id: str,
    generation_number: int,
    generation_roman: str | None,
) -> dict[str, Any]:
    return {
        "internalId": internal_id,
        "generation": {
            "number": generation_number,
            "roman": generation_roman,
        },
        "fill": {"current": 0, "cap": 0},
        "leaderWindowEndsAt": None,
        "ranks": [],
    }


def _payload_from_row(row) -> dict[str, Any]:
    return {
        "internalId": row.internal_id,
        "generation": {
            "number": row.generation_number,
            "roman": row.generation_roman,
        },
        "fill": {
            "current": row.fill_current,
            "cap": row.fill_cap,
        },
        "leaderWindowEndsAt": (
            row.leader_window_ends_at.isoformat()
            if row.leader_window_ends_at is not None
            else None
        ),
        "ranks": [
            {
                "rank": r.rank,
                "displayLabel": r.display_label,
                "masteryPoints": r.mastery_points,
            }
            for r in sorted(row.ranks, key=lambda x: x.rank)
        ],
    }


def get_design_standings(internal_id: str) -> dict[str, Any]:
    design_id = (internal_id or "").strip()
    if not design_id:
        raise AppError(INVALID_QUERY, message="internal_id is required")

    try:
        design = get_design(design_id)
    except AppError as err:
        if err.code == CATALOG_NOT_FOUND.code:
            raise AppError(
                CATALOG_NOT_FOUND,
                message=f"Design not found: {design_id}",
            ) from err
        raise

    gen_num, gen_roman = _generation_from_design(design)
    with session_scope() as session:
        row = repo.get_standing(
            session,
            internal_id=design_id,
            generation_number=gen_num,
        )
        if row is None:
            return _empty_payload(
                internal_id=design_id,
                generation_number=gen_num,
                generation_roman=gen_roman,
            )
        return _payload_from_row(row)


def clear_design_standings(
    internal_id: str,
    *,
    generation_number: int | None = None,
) -> dict[str, Any]:
    """Internal apply: delete standings (+ ranks via CASCADE) for a design."""
    design_id = (internal_id or "").strip()
    if not design_id:
        raise AppError(INVALID_QUERY, message="internal_id is required")
    with session_scope() as session:
        deleted = repo.clear_standing(
            session,
            internal_id=design_id,
            generation_number=generation_number,
        )
    return {"internalId": design_id, "deleted": deleted}


def replace_design_standings(
    internal_id: str,
    *,
    generation_number: int,
    generation_roman: str | None = None,
    fill_current: int = 0,
    fill_cap: int = 0,
    leader_window_ends_at: datetime | None = None,
    ranks: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Internal apply: replace standings snapshot for a design generation."""
    design_id = (internal_id or "").strip()
    if not design_id:
        raise AppError(INVALID_QUERY, message="internal_id is required")
    if generation_number < 1:
        raise AppError(INVALID_QUERY, message="generation_number must be >= 1")
    if fill_current < 0 or fill_cap < 0:
        raise AppError(INVALID_QUERY, message="fill values must be >= 0")

    rank_rows = ranks or []
    normalized: list[dict[str, Any]] = []
    for item in rank_rows:
        if not isinstance(item, dict):
            continue
        label = str(item.get("display_label") or item.get("displayLabel") or "").strip()
        if not label:
            continue
        try:
            rank_n = int(item.get("rank", 0))
            points = int(item.get("mastery_points") or item.get("masteryPoints") or 0)
        except (TypeError, ValueError) as exc:
            raise AppError(INVALID_QUERY, message="invalid rank payload") from exc
        if rank_n < 1 or points < 0:
            raise AppError(INVALID_QUERY, message="invalid rank values")
        normalized.append(
            {
                "rank": rank_n,
                "display_label": label,
                "mastery_points": points,
            }
        )
    normalized.sort(key=lambda r: r["rank"])

    with session_scope() as session:
        row = repo.replace_standing(
            session,
            internal_id=design_id,
            generation_number=generation_number,
            generation_roman=generation_roman,
            fill_current=fill_current,
            fill_cap=fill_cap,
            leader_window_ends_at=leader_window_ends_at,
            ranks=normalized,
        )
        return _payload_from_row(row)
