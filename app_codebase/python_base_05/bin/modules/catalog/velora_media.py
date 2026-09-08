"""Velora media URLs + mtime-cached location listing (same posture as catalog art)."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from core.utils.dev_logger import customlog

LOGGING_SWITCH = True

_PUBLIC_PREFIX = "/catalog-media/velora"

# dir_key -> (dir_mtime_ns, sorted file names)
_listing_cache: dict[str, tuple[int, list[str]]] = {}


def clear_caches() -> None:
    _listing_cache.clear()


def velora_media_root() -> Path:
    raw = os.environ.get("CATALOG_VELORA_MEDIA_ROOT", "").strip()
    if raw:
        return Path(raw)
    return Path("/data/catalog-velora")


def _fingerprint(path: Path) -> tuple[int, int]:
    st = path.stat()
    mtime_ns = getattr(st, "st_mtime_ns", int(st.st_mtime * 1_000_000_000))
    return mtime_ns, st.st_size


def arena_image_url(*, slug: str, arena_id: str, image_file: str | None = None) -> str:
    """Public arena art path under /catalog-media/velora/arenas/…"""
    file_name = (image_file or "").strip() or f"{arena_id.strip()}.webp"
    if "/" in file_name or "\\" in file_name or file_name.startswith("."):
        file_name = f"{arena_id.strip()}.webp"
    return f"{_PUBLIC_PREFIX}/arenas/{slug.strip()}/{file_name}"


def region_image_url(*, slug: str) -> str:
    return f"{_PUBLIC_PREFIX}/regions/{slug.strip()}/region.png"


def location_image_url(*, slug: str, file_name: str) -> str:
    return f"{_PUBLIC_PREFIX}/regions/{slug.strip()}/locations/{file_name.strip()}"


def map_image_url(*, file_name: str) -> str:
    return f"{_PUBLIC_PREFIX}/maps/{file_name.strip()}"


def _list_png_names(directory: Path) -> list[str]:
    """Mtime-cached listing of *.png filenames in a directory (non-recursive)."""
    if not directory.is_dir():
        return []
    key = str(directory.resolve())
    try:
        mtime_ns, _ = _fingerprint(directory)
    except OSError:
        return []

    cached = _listing_cache.get(key)
    if cached is not None and cached[0] == mtime_ns:
        return list(cached[1])

    names: list[str] = []
    try:
        for path in sorted(directory.iterdir()):
            if not path.is_file():
                continue
            if path.name.startswith("."):
                continue
            if path.suffix.lower() != ".png":
                continue
            names.append(path.name)
    except OSError:
        return []

    try:
        mtime_ns, _ = _fingerprint(directory)
    except OSError:
        pass
    _listing_cache[key] = (mtime_ns, names)
    return list(names)


def list_region_locations(*, slug: str) -> list[dict[str, Any]]:
    """Scan regions/{slug}/locations/*.png → {id, fileName, name, imageUrl}."""
    region_slug = slug.strip()
    if not region_slug:
        return []
    root = velora_media_root() / "regions" / region_slug / "locations"
    out: list[dict[str, Any]] = []
    for name in _list_png_names(root):
        stem = name[: -len(".png")] if name.lower().endswith(".png") else name
        out.append(
            {
                "id": stem,
                "fileName": name,
                "name": stem.replace("-", " ").replace("_", " ").title(),
                "imageUrl": location_image_url(slug=region_slug, file_name=name),
            }
        )
    if LOGGING_SWITCH and out:
        customlog(f"catalog: velora locations slug={region_slug} n={len(out)}")
    return out


def list_world_maps() -> list[dict[str, Any]]:
    """Scan maps/*.png → {id, fileName, name, imageUrl}."""
    root = velora_media_root() / "maps"
    out: list[dict[str, Any]] = []
    for name in _list_png_names(root):
        stem = name[: -len(".png")] if name.lower().endswith(".png") else name
        out.append(
            {
                "id": stem,
                "fileName": name,
                "name": stem.replace("-", " ").replace("_", " ").title(),
                "imageUrl": map_image_url(file_name=name),
            }
        )
    return out


def enrich_regions_meta(regions_doc: Any) -> Any:
    """Attach derived imageUrl / locations to regions meta (design-style client fields)."""
    if not isinstance(regions_doc, dict):
        return regions_doc
    out = dict(regions_doc)
    regions_out: list[Any] = []
    for region in out.get("regions") or []:
        if not isinstance(region, dict):
            regions_out.append(region)
            continue
        row = dict(region)
        slug = str(row.get("slug") or "").strip()
        if slug:
            row["imageUrl"] = region_image_url(slug=slug)
            row["locations"] = list_region_locations(slug=slug)
        arenas_out: list[Any] = []
        for arena in row.get("arenas") or []:
            if not isinstance(arena, dict):
                arenas_out.append(arena)
                continue
            arena_row = dict(arena)
            arena_id = str(arena_row.get("arenaId") or "").strip()
            image_file = str(arena_row.get("imageFile") or "").strip() or None
            if slug and arena_id:
                arena_row["imageUrl"] = arena_image_url(
                    slug=slug,
                    arena_id=arena_id,
                    image_file=image_file,
                )
            arenas_out.append(arena_row)
        row["arenas"] = arenas_out
        regions_out.append(row)
    out["regions"] = regions_out

    assets = out.get("arenaAssets")
    if isinstance(assets, dict):
        assets_out = dict(assets)
        assets_out["publicPrefix"] = f"{_PUBLIC_PREFIX}/arenas/{{region-slug}}/"
        assets_out["publicFile"] = "{arenaId}.webp"
        out["arenaAssets"] = assets_out

    out["maps"] = list_world_maps()
    out["regionAssets"] = {
        "publicPrefix": f"{_PUBLIC_PREFIX}/regions/{{region-slug}}/",
        "regionFile": "region.png",
        "locationsDirectory": "locations/",
    }
    out["mapAssets"] = {
        "publicPrefix": f"{_PUBLIC_PREFIX}/maps/",
        "file": "{name}.png",
    }
    return out
