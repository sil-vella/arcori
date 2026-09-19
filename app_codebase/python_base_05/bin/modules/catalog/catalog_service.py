"""Catalog read service — index, theme, design; strips artworkPrompt for clients."""

from __future__ import annotations

import json
from typing import Any

from core.errors.app_error import AppError
from modules.catalog import catalog_loader as loader
from modules.catalog.catalog_ids import art_basename
from modules.catalog.catalog_errors import INVALID_QUERY, LOAD_FAILED, NOT_FOUND
from modules.catalog.current_series import current_series_key, media_folder_for_series
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
    """Public path: /catalog-media/{media_folder}/{theme}/{artBasename}.webp

    Art files stay on the pre-GEN basename (``ANM-TIG-SER001-0001.webp``) so
    echoes reuse GEN001 artwork under the read-only catalog-media mount.
    """
    stem = art_basename(internal_id) or internal_id.strip()
    return (
        f"/catalog-media/{media_folder_for_series(series_key)}/"
        f"{_slug(theme)}/{stem}.webp"
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
    # Face media: webp and/or Lottie for any theme (not Kin-only).
    face_media = str(design.get("faceMedia") or "").strip().lower() or None
    lottie_url = design.get("lottieUrl")
    theme_code = str(design.get("themeCode") or "").strip().upper()
    theme_l = str(design.get("theme") or theme_name or "").strip().lower()
    is_kin = (
        theme_code == "KIN"
        or theme_l == "kin"
        or internal_id.upper().startswith("KIN-")
    )
    if is_kin and internal_id:
        from modules.catalog.kin_design_store import lottie_public_url

        out["lottieUrl"] = lottie_public_url(internal_id)
        out["faceMedia"] = "lottie"
    else:
        if isinstance(lottie_url, str) and lottie_url.strip():
            out["lottieUrl"] = lottie_url.strip()
        if face_media in ("webp", "lottie"):
            out["faceMedia"] = face_media
        elif out.get("lottieUrl"):
            out["faceMedia"] = "lottie"
        elif out.get("imageUrl"):
            out["faceMedia"] = "webp"
    return out


def get_meta() -> dict[str, Any]:
    themes = _load_guarded(loader.load_meta, "themes_subthemes")
    regions = enrich_regions_meta(_load_guarded(loader.load_meta, "regions"))
    kin = _load_guarded(loader.load_meta, "kin")
    return strip_for_client(
        {
            "themes_subthemes": themes,
            "regions": regions,
            "kin": kin,
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
    from core.state.session_scope import session_scope
    from modules.catalog import catalog_repository as catalog_repo

    with session_scope() as session:
        rows = catalog_repo.list_designs(
            session,
            series=series_filter,
            theme=theme_filter,
            subtheme=subtheme_filter,
            circulating=circulating,
        )
        for row in rows:
            design = dict(row.design_json or {})
            items.append(
                design_summary(
                    design,
                    series_key=row.series_key,
                    theme=row.theme or str(design.get("theme") or ""),
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


def _theme_lore(theme_code: str) -> str | None:
    """Theme-level lore from 00_themes_subthemes.json, if authored."""
    code = (theme_code or "").strip().upper()
    if not code:
        return None
    meta = _load_guarded(loader.load_meta, "themes_subthemes")
    rows = meta.get("themes") if isinstance(meta, dict) else None
    if not isinstance(rows, list):
        return None
    for row in rows:
        if not isinstance(row, dict):
            continue
        if str(row.get("themeCode") or "").strip().upper() != code:
            continue
        lore = str(row.get("loreDescription") or "").strip()
        return lore or None
    return None


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

    from core.state.session_scope import session_scope
    from modules.catalog import catalog_repository as catalog_repo

    with session_scope() as session:
        rows = catalog_repo.list_by_theme_code(session, code)
        if not rows:
            raise AppError(NOT_FOUND, message=f"Theme not found: {code}")
        first = rows[0]
        series_key = first.series_key
        theme_name = first.theme
        theme_code_out = first.theme_code
        designs: list[dict[str, Any]] = []
        for row in rows:
            design = strip_for_client(dict(row.design_json or {}))
            if not isinstance(design, dict):
                continue
            internal_id = str(design.get("internalId") or row.internal_id)
            d_theme = str(design.get("theme") or theme_name)
            design = dict(design)
            design["seriesKey"] = series_key
            if internal_id:
                design["imageUrl"] = image_url_for(
                    series_key=series_key,
                    theme=d_theme,
                    internal_id=internal_id,
                )
            _attach_face_media(design, internal_id)
            designs.append(design)
        out = {
            "theme": theme_name,
            "themeCode": theme_code_out,
            "series": series_key,
            "seriesKey": series_key,
            "version": first.catalog_version,
            "designs": designs,
        }
        lore = _theme_lore(theme_code_out)
        if lore:
            out["loreDescription"] = lore
        return out


def _attach_face_media(out: dict[str, Any], design_id: str) -> None:
    """Stamp faceMedia / lottieUrl for any design that uses Lottie (Kin or regular).

    Kin resolves the public URL via the upload store (GEN-stripped art basename).
    Regular designs keep ``lottieUrl`` / ``faceMedia`` from the catalog doc.
    """
    theme_code = str(out.get("themeCode") or "").strip().upper()
    theme_l = str(out.get("theme") or "").strip().lower()
    iid = (design_id or str(out.get("internalId") or "")).strip()
    if not iid:
        return
    is_kin = theme_code == "KIN" or theme_l == "kin" or iid.upper().startswith("KIN-")
    if is_kin:
        from modules.catalog.kin_design_store import lottie_public_url

        out["lottieUrl"] = lottie_public_url(iid)
        out["faceMedia"] = "lottie"
        return

    face_media = str(out.get("faceMedia") or "").strip().lower() or None
    lottie_url = out.get("lottieUrl")
    has_lottie = isinstance(lottie_url, str) and lottie_url.strip()
    if face_media in ("webp", "lottie"):
        out["faceMedia"] = face_media
    elif has_lottie:
        out["faceMedia"] = "lottie"
    elif isinstance(out.get("imageUrl"), str) and str(out.get("imageUrl") or "").strip():
        out["faceMedia"] = "webp"
    if has_lottie:
        out["lottieUrl"] = str(lottie_url).strip()


def get_design(internal_id: str) -> dict[str, Any]:
    design_id = (internal_id or "").strip()
    if not design_id:
        raise AppError(INVALID_QUERY, message="internal_id is required")

    from core.state.session_scope import session_scope
    from modules.catalog import catalog_repository as catalog_repo
    from models.catalog_design import WORLD_CLOSED

    with session_scope() as session:
        # Prefer Closed alias (GEN / non-GEN cutover) so preserved pieces
        # cannot resolve as Active via a leftover id form.
        row = catalog_repo.get_by_id_or_alias(session, design_id)
        if row is not None:
            out = strip_for_client(dict(row.design_json or {}))
            if str(row.world_state or "").strip() == WORLD_CLOSED:
                out["worldState"] = WORLD_CLOSED
            series_key = row.series_key
            theme_name = row.theme or str(out.get("theme") or "")
            out["seriesKey"] = series_key
            out["catalogVersion"] = row.catalog_version
            out["imageUrl"] = image_url_for(
                series_key=series_key,
                theme=theme_name,
                internal_id=row.internal_id,
            )
            _attach_face_media(out, row.internal_id)
            return out

    player_design = _resolve_player_kin_design(design_id)
    if player_design is None:
        # Also try GEN-stripped / GEN001 variants for Kin media lookup.
        try:
            from modules.catalog.catalog_ids import art_basename

            alt = art_basename(design_id)
            if alt and alt != design_id:
                player_design = _resolve_player_kin_design(alt)
        except Exception:
            player_design = None
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
    _attach_face_media(out, design_id)
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
