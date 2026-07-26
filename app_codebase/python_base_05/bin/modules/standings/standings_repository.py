"""SQLAlchemy access for design standings."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.orm import Session, selectinload

from models.design_standing import DesignStanding, DesignStandingRank


def get_standing(
    session: Session,
    *,
    internal_id: str,
    generation_number: int,
) -> DesignStanding | None:
    stmt = (
        select(DesignStanding)
        .where(
            DesignStanding.internal_id == internal_id,
            DesignStanding.generation_number == generation_number,
        )
        .options(selectinload(DesignStanding.ranks))
    )
    return session.scalars(stmt).first()


def clear_standing(
    session: Session,
    *,
    internal_id: str,
    generation_number: int | None = None,
) -> int:
    stmt = delete(DesignStanding).where(DesignStanding.internal_id == internal_id)
    if generation_number is not None:
        stmt = stmt.where(DesignStanding.generation_number == generation_number)
    result = session.execute(stmt)
    return int(result.rowcount or 0)


def replace_standing(
    session: Session,
    *,
    internal_id: str,
    generation_number: int,
    generation_roman: str | None,
    fill_current: int,
    fill_cap: int,
    leader_window_ends_at: datetime | None,
    ranks: list[dict[str, Any]],
) -> DesignStanding:
    clear_standing(
        session,
        internal_id=internal_id,
        generation_number=generation_number,
    )
    row = DesignStanding(
        internal_id=internal_id,
        generation_number=generation_number,
        generation_roman=generation_roman,
        fill_current=fill_current,
        fill_cap=fill_cap,
        leader_window_ends_at=leader_window_ends_at,
    )
    session.add(row)
    session.flush()
    for item in ranks:
        session.add(
            DesignStandingRank(
                standing_id=row.id,
                rank=int(item["rank"]),
                display_label=str(item["display_label"]),
                mastery_points=int(item.get("mastery_points", 0)),
            )
        )
    session.flush()
    session.refresh(row)
    return get_standing(
        session,
        internal_id=internal_id,
        generation_number=generation_number,
    ) or row
