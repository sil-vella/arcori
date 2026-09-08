"""Catalog read service — index, theme, design; strips artworkPrompt for clients."""

from __future__ import annotations

import json
from typing import Any

from core.errors.app_error import AppError
from modules.catalog import catalog_loader as loader
from modules.catalog.catalog_errors import INVALID_QUERY, LOAD_FAILED, NOT_FOUND
from modules.catalog.current_series import current_series_key
from modules.catalog.velora_media import enrich_regions_meta

_CLIENT_OMIT_KEYS = frozenset({"artworkPrompt"})


def _load_guarded(fn, *args, **kwargs):
    try:
        return fn(*args, **kwargs)
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
        raise AppError(LOAD_FAILED, message=str(exc) or LOAD_FAILED.message) from exc


def strip_for_client(value: Any) -> Any:
    """Deep-copy-ish strip of artworkPrompt from dict/list trees."""
    if isinstance(value, dict):
        return {
            k: strip_for_client(v)
            for k, v in value.items()
            if k not in _CLIENT_OMIT_KEYS
        }
    if isinstance(value, list):
        return [strip_for_client(item) for item in value]
    return value


def _slug(value: str) -> str:
    return value.strip().lower().replace(" ", "_")


def image_url_for(*, series_key: str, theme: str, internal_id: str) -> str:
    """Public path: /catalog-media/{series}/{theme}/{internalId}.webp"""
    return (
        f"/catalog-media/{_slug(series_key)}/{_slug(theme)}/{internal_id.strip()}.webp"
    )


def design_summary(
    design: dict[str, Any],
    *,
    series_key: str,
    theme: str,
) -> dict[str, Any]:
    generation = design.get("generation")
    gen_out: dict[str, Any] | None = None
    if isinstance(generation, dict):
        gen_out = {
            "roman": generation.get("roman"),
            "number": generation.get("number"),
        }
    internal_id = str(design.get("internalId") or "")
    theme_name = str(design.get("theme") or theme)
    out: dict[str, Any] = {
        "internalId": design.get("internalId"),
        "themeCode": design.get("themeCode"),
        "designCode": design.get("designCode"),
        "designFamily": design.get("designFamily"),
        "design": design.get("design"),
        "theme": design.get("theme"),
        "subtheme": design.get("subtheme"),
        "printedRarity": design.get("printedRarity"),
        "selectionWeight": design.get("selectionWeight"),
        "series": design.get("series"),
        "seriesKey": series_key,
        "worldState": design.get("worldState"),
        "seasonState": design.get("seasonState"),
        "type": design.get("type"),
        "color": design.get("color"),
        "generation": gen_out,
        "imageUrl": image_url_for(
            series_key=series_key,
            theme=theme_name,
            internal_id=internal_id,
        )
        if internal_id
        else None,
    }
    # Kin face is Lottie; attach computed URL (not a design-doc field).
    theme_code = str(design.get("themeCode") or "").strip().upper()
    if theme_code == "KIN" and internal_id:
        from modules.catalog.kin_design_store import lottie_public_url

        out["lottieUrl"] = lottie_public_url(internal_id)
    return out


def get_meta() -> dict[str, Any]:
    themes = _load_guarded(loader.load_meta, "themes_subthemes")
    regions = enrich_regions_meta(_load_guarded(loader.load_meta, "regions"))
    kin = _load_guarded(loader.load_meta, "kin")
    rarities = _load_guarded(loader.load_meta, "printed_rarity")
    return strip_for_client(
        {
            "themes_subthemes": themes,
            "regions": regions,
            "kin": kin,
            "printed_rarity": rarities,
        }
    )


def get_index(
    *,
    series: str | None = None,
    theme: str | None = None,
    subtheme: str | None = None,
    circulating: bool = False,
    limit: int | None = None,
    offset: int = 0,
) -> dict[str, Any]:
    if offset < 0:
        raise AppError(INVALID_QUERY, message="offset must be >= 0")
    if limit is not None and limit < 0:
        raise AppError(INVALID_QUERY, message="limit must be >= 0")

    series_filter = series.strip().lower() if series else None
    theme_filter = theme.strip().lower() if theme else None
    subtheme_filter = subtheme.strip().lower() if subtheme else None

    items: list[dict[str, Any]] = []
    docs = _load_guarded(loader.list_theme_documents)
    for doc in docs:
        designs = doc.get("designs")
        if not isinstance(designs, list):
            continue
        doc_theme = str(doc.get("theme", ""))
        doc_theme_l = doc_theme.lower()
        series_key = str(doc.get("series") or "").strip() or "Unknown"
        series_key_l = series_key.lower()
        doc_series_blob = str(doc.get("catalog", series_key)).lower()
        for design in designs:
            if not isinstance(design, dict):
                continue
            if circulating:
                world = str(design.get("worldState", "")).strip().lower()
                if world != "active":
                    continue
            if theme_filter:
                d_theme = str(design.get("theme", doc_theme)).lower()
                d_code = str(design.get("themeCode", doc.get("themeCode", ""))).lower()
                if theme_filter not in (d_theme, d_code) and theme_filter != doc_theme_l:
                    continue
            if series_filter:
                d_series = str(design.get("series", "")).lower()
                if (
                    series_filter not in (d_series, series_key_l, doc_series_blob)
                    and series_filter not in doc_series_blob
                ):
                    continue
            if subtheme_filter:
                d_sub = str(design.get("subtheme", "")).lower()
                if d_sub != subtheme_filter:
                    continue
            items.append(
                design_summary(
                    design,
                    series_key=series_key,
                    theme=doc_theme or str(design.get("theme") or ""),
                )
            )

    # Player Kin: one JSON file per design (no shared category file).
    if _should_include_player_kins(theme_filter):
        items.extend(_player_kin_index_items(
            circulating=circulating,
            theme_filter=theme_filter,
            series_filter=series_filter,
            subtheme_filter=subtheme_filter,
        ))

    total = len(items)
    if offset:
        items = items[offset:]
    if limit is not None:
        items = items[:limit]

    return {"items": items, "total": total, "offset": offset, "limit": limit}


def _should_include_player_kins(theme_filter: str | None) -> bool:
    # No theme filter → include alongside other circulating designs.
    # Explicit Kin / KIN theme → player Kin files only for that theme.
    if theme_filter is None:
        return True
    return theme_filter == "kin"


def _player_kin_index_items(
    *,
    circulating: bool,
    theme_filter: str | None,
    series_filter: str | None,
    subtheme_filter: str | None,
) -> list[dict[str, Any]]:
    from modules.catalog.kin_design_store import list_design_files

    items: list[dict[str, Any]] = []
    for design in list_design_files():
        if circulating:
            world = str(design.get("worldState", "")).strip().lower()
            if world != "active":
                continue
        if theme_filter:
            d_theme = str(design.get("theme") or "").lower()
            d_code = str(design.get("themeCode") or "").lower()
            if theme_filter not in (d_theme, d_code):
                continue
        if series_filter:
            d_series = str(design.get("series") or "").lower()
            if series_filter not in (d_series, "genesis") and "genesis" not in d_series:
                continue
        if subtheme_filter:
            d_sub = str(design.get("subtheme", "")).lower()
            if d_sub != subtheme_filter:
                continue
        items.append(
            design_summary(
                design,
                series_key=current_series_key(),
                theme=str(design.get("theme") or "Kin"),
            )
        )
    return items


def get_theme(theme_code: str) -> dict[str, Any]:
    code = (theme_code or "").strip()
    if not code:
        raise AppError(INVALID_QUERY, message="theme code is required")
    doc = _load_guarded(loader.find_theme_document_by_code, code)
    if doc is None:
        raise AppError(NOT_FOUND, message=f"Theme not found: {code}")
    out = strip_for_client(doc)
    series_key = str(doc.get("series") or "").strip() or "Unknown"
    theme_name = str(doc.get("theme") or "")
    designs = out.get("designs")
    if isinstance(designs, list):
        enriched = []
        for design in designs:
            if not isinstance(design, dict):
                continue
            internal_id = str(design.get("internalId") or "")
            d_theme = str(design.get("theme") or theme_name)
            design = dict(design)
            design["seriesKey"] = series_key
            if internal_id:
                design["imageUrl"] = image_url_for(
                    series_key=series_key,
                    theme=d_theme,
                    internal_id=internal_id,
                )
            enriched.append(design)
        out["designs"] = enriched
    return out


def get_design(internal_id: str) -> dict[str, Any]:
    design_id = (internal_id or "").strip()
    if not design_id:
        raise AppError(INVALID_QUERY, message="internal_id is required")
    found = _load_guarded(loader.find_design_with_document, design_id)
    if found is None:
        player_design = _resolve_player_kin_design(design_id)
        if player_design is None:
            raise AppError(NOT_FOUND, message=f"Design not found: {design_id}")
        out = strip_for_client(player_design)
        series_key = current_series_key()
        theme_name = str(player_design.get("theme") or "Kin")
        out["seriesKey"] = series_key
        out["catalogVersion"] = 1
        out["imageUrl"] = image_url_for(
            series_key=series_key,
            theme=theme_name,
            internal_id=design_id,
        )
        from modules.catalog.kin_design_store import lottie_public_url

        out["lottieUrl"] = lottie_public_url(design_id)
        return out
    design, doc = found
    out = strip_for_client(design)
    series_key = str(doc.get("series") or "").strip() or "Unknown"
    theme_name = str(design.get("theme") or doc.get("theme") or "")
    out["seriesKey"] = series_key
    out["catalogVersion"] = doc.get("version")
    out["imageUrl"] = image_url_for(
        series_key=series_key,
        theme=theme_name,
        internal_id=design_id,
    )
    return out


def _resolve_player_kin_design(design_id: str) -> dict[str, Any] | None:
    """Prefer per-file design JSON; fall back to player_kin.catalog_design."""
    from modules.catalog.kin_design_store import read_design_file

    file_design = read_design_file(design_id)
    if file_design is not None:
        return file_design
    return _player_kin_catalog_design(design_id)


def _player_kin_catalog_design(design_id: str) -> dict[str, Any] | None:
    """Overlay: player-created Kin designs stored on player_kin.catalog_design."""
    from core.state.session_scope import session_scope
    from modules.avari import avari_repository as avari_repo

    try:
        with session_scope() as session:
            row = avari_repo.find_player_kin_by_design_id(session, design_id)
            if row is None or not row.catalog_design:
                return None
            return dict(row.catalog_design)
    except Exception:
        return None


def get_designs_batch(ids: list[str] | None) -> dict[str, Any]:
    """Fail-closed batch fetch for Dart match freeze (service tier)."""
    if not isinstance(ids, list) or not ids:
        raise AppError(INVALID_QUERY, message="ids must be a non-empty list")

    cleaned: list[str] = []
    seen: set[str] = set()
    for raw in ids:
        design_id = str(raw or "").strip()
        if not design_id:
            raise AppError(INVALID_QUERY, message="ids must not contain empty values")
        if design_id in seen:
            continue
        seen.add(design_id)
        cleaned.append(design_id)

    if not cleaned:
        raise AppError(INVALID_QUERY, message="ids must be a non-empty list")

    designs: dict[str, Any] = {}
    for design_id in cleaned:
        designs[design_id] = get_design(design_id)
    return {"designs": designs}
