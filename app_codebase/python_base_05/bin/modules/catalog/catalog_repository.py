"""DB access for catalog_designs (runtime catalog SSOT)."""

from __future__ import annotations

from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from models.catalog_design import (
    SOURCE_ECHO,
    WORLD_ACTIVE,
    WORLD_CLOSED,
    CatalogDesign,
)
from modules.catalog.catalog_ids import (
    design_id_aliases,
    ensure_gen001,
    generation_number_from_id,
    parse_design_id,
)


def get_by_id(session: Session, internal_id: str) -> CatalogDesign | None:
    iid = (internal_id or "").strip()
    if not iid:
        return None
    return session.get(CatalogDesign, iid)


def get_by_id_or_alias(session: Session, internal_id: str) -> CatalogDesign | None:
    """Resolve a catalog row, preferring a Closed alias when present."""
    aliases = design_id_aliases(internal_id)
    closed: CatalogDesign | None = None
    first: CatalogDesign | None = None
    for lid in aliases:
        row = get_by_id(session, lid)
        if row is None:
            continue
        if first is None:
            first = row
        if str(row.world_state or "").strip() == WORLD_CLOSED:
            closed = row
            break
    return closed if closed is not None else first


def list_designs(
    session: Session,
    *,
    series: str | None = None,
    theme: str | None = None,
    subtheme: str | None = None,
    circulating: bool = False,
) -> list[CatalogDesign]:
    stmt = select(CatalogDesign)
    if circulating:
        stmt = stmt.where(CatalogDesign.world_state == WORLD_ACTIVE)
    theme_f = (theme or "").strip()
    if theme_f:
        tl = theme_f.lower()
        stmt = stmt.where(
            (CatalogDesign.theme_code.ilike(tl))
            | (CatalogDesign.theme.ilike(tl))
        )
    series_f = (series or "").strip()
    if series_f:
        sl = series_f.lower()
        stmt = stmt.where(CatalogDesign.series_key.ilike(f"%{sl}%"))
    rows = list(session.scalars(stmt).all())
    if subtheme:
        sub_l = subtheme.strip().lower()
        rows = [
            r
            for r in rows
            if str((r.design_json or {}).get("subtheme") or "").lower() == sub_l
        ]
    return rows


def list_by_theme_code(session: Session, theme_code: str) -> list[CatalogDesign]:
    code = (theme_code or "").strip()
    if not code:
        return []
    return list(
        session.scalars(
            select(CatalogDesign).where(CatalogDesign.theme_code.ilike(code))
        ).all()
    )


def all_internal_ids(session: Session) -> set[str]:
    return set(session.scalars(select(CatalogDesign.internal_id)).all())


def upsert_design(
    session: Session,
    *,
    design: dict[str, Any],
    series_key: str,
    source: str,
    parent_internal_id: str | None = None,
    catalog_version: int | None = None,
    overwrite: bool = False,
) -> CatalogDesign | None:
    """Insert design if missing. When overwrite=False, never replace echo rows."""
    raw_id = str(design.get("internalId") or "").strip()
    if not raw_id:
        return None
    iid = ensure_gen001(raw_id)
    payload = dict(design)
    payload["internalId"] = iid
    existing = session.get(CatalogDesign, iid)
    if existing is not None:
        if not overwrite:
            return existing
        if existing.source == SOURCE_ECHO and source != SOURCE_ECHO:
            return existing
        existing.design_json = payload
        existing.world_state = str(payload.get("worldState") or WORLD_ACTIVE)
        existing.generation_number = generation_number_from_id(iid)
        existing.series_key = series_key
        existing.theme = str(payload.get("theme") or existing.theme)
        existing.theme_code = str(payload.get("themeCode") or existing.theme_code)
        existing.design_code = str(payload.get("designCode") or "")
        if catalog_version is not None:
            existing.catalog_version = catalog_version
        if parent_internal_id:
            existing.parent_internal_id = parent_internal_id
        existing.source = source
        session.flush()
        return existing

    theme = str(payload.get("theme") or "").strip() or "Unknown"
    theme_code = str(payload.get("themeCode") or "").strip()
    if not theme_code:
        parsed = parse_design_id(iid)
        theme_code = parsed.theme_code if parsed else "UNK"
    row = CatalogDesign(
        internal_id=iid,
        series_key=(series_key or "Unknown").strip() or "Unknown",
        theme=theme,
        theme_code=theme_code,
        design_code=str(payload.get("designCode") or ""),
        generation_number=generation_number_from_id(iid),
        world_state=str(payload.get("worldState") or WORLD_ACTIVE),
        design_json=payload,
        source=source,
        parent_internal_id=parent_internal_id,
        catalog_version=catalog_version,
    )
    session.add(row)
    session.flush()
    return row


def mark_closed(session: Session, internal_id: str) -> CatalogDesign | None:
    """Mark this design Closed across GEN / non-GEN id aliases."""
    closed: CatalogDesign | None = None
    for iid in design_id_aliases(internal_id):
        row = get_by_id(session, iid)
        if row is None:
            continue
        row.world_state = WORLD_CLOSED
        payload = dict(row.design_json or {})
        payload["worldState"] = WORLD_CLOSED
        row.design_json = payload
        closed = row
    if closed is not None:
        session.flush()
    return closed


def insert_echo(
    session: Session,
    *,
    design: dict[str, Any],
    series_key: str,
    parent_internal_id: str,
    catalog_version: int | None = None,
) -> CatalogDesign:
    """Insert echo design; no-op return if already present."""
    iid = str(design.get("internalId") or "").strip()
    existing = get_by_id(session, iid)
    if existing is not None:
        return existing
    row = upsert_design(
        session,
        design=design,
        series_key=series_key,
        source=SOURCE_ECHO,
        parent_internal_id=parent_internal_id,
        catalog_version=catalog_version,
        overwrite=False,
    )
    assert row is not None
    return row


def copy_design_access(
    session: Session,
    *,
    from_design_id: str,
    to_design_id: str,
) -> int:
    """Copy player_design_access rows from closed → echo. Returns inserted count."""
    from models.player_progress import PlayerDesignAccess

    src_ids = design_id_aliases(from_design_id)
    dst = (to_design_id or "").strip()
    if not src_ids or not dst:
        return 0
    rows = list(
        session.scalars(
            select(PlayerDesignAccess).where(
                PlayerDesignAccess.design_id.in_(src_ids)
            )
        ).all()
    )
    inserted = 0
    for row in rows:
        if str(row.design_id or "").strip() == dst:
            continue
        stmt = (
            pg_insert(PlayerDesignAccess)
            .values(
                user_id=row.user_id,
                design_id=dst,
                source=row.source,
            )
            .on_conflict_do_nothing(
                constraint="uq_player_design_access_user_design"
            )
        )
        result = session.execute(stmt)
        if result.rowcount and result.rowcount > 0:
            inserted += 1
    session.flush()
    return inserted


def revoke_all_access_for_design(session: Session, design_id: str) -> int:
    """Delete every player_design_access row for this design (all id aliases)."""
    from models.player_progress import PlayerDesignAccess

    ids = design_id_aliases(design_id)
    if not ids:
        return 0
    rows = list(
        session.scalars(
            select(PlayerDesignAccess).where(
                PlayerDesignAccess.design_id.in_(ids)
            )
        ).all()
    )
    for row in rows:
        session.delete(row)
    session.flush()
    return len(rows)
