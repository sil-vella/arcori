"""Mtime-fingerprint JSON loader for catalog data files."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

# path_str -> (mtime_ns, size, parsed)
_file_cache: dict[str, tuple[int, int, Any]] = {}
# series_dir_str -> (dir_mtime_ns, sorted relative paths)
_listing_cache: dict[str, tuple[int, list[str]]] = {}

_data_root_override: Path | None = None

_META_FILES = {
    "themes_subthemes": "00_themes_subthemes.json",
    "regions": "01_regions.json",
    "kin": "02_kin.json",
    "printed_rarity": "03_printed_rarity.json",
}


def default_data_root() -> Path:
    return Path(__file__).resolve().parent / "data"


def get_data_root() -> Path:
    env = os.environ.get("CATALOG_DATA_ROOT", "").strip()
    if env:
        return Path(env).expanduser().resolve()
    if _data_root_override is not None:
        return _data_root_override
    return default_data_root()


def set_data_root_override(root: Path | None) -> None:
    """Test helper: pin catalog root (None clears). Also clears caches."""
    global _data_root_override
    _data_root_override = root.resolve() if root is not None else None
    clear_caches()


def clear_caches() -> None:
    _file_cache.clear()
    _listing_cache.clear()


def _fingerprint(path: Path) -> tuple[int, int]:
    st = path.stat()
    mtime_ns = getattr(st, "st_mtime_ns", int(st.st_mtime * 1_000_000_000))
    return mtime_ns, st.st_size


def load_json_file(path: Path) -> Any:
    """Load JSON with per-file mtime/size cache. Raises OSError/json.JSONDecodeError."""
    resolved = path.resolve()
    key = str(resolved)
    mtime_ns, size = _fingerprint(resolved)
    cached = _file_cache.get(key)
    if cached is not None and cached[0] == mtime_ns and cached[1] == size:
        return cached[2]
    with resolved.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    _file_cache[key] = (mtime_ns, size, data)
    return data


def load_meta(name: str) -> Any:
    """Load a rooted meta file by logical name (themes_subthemes, regions, kin, printed_rarity)."""
    filename = _META_FILES.get(name)
    if filename is None:
        raise KeyError(f"Unknown meta name: {name}")
    return load_json_file(get_data_root() / filename)


def _series_listing_fingerprint(series_dir: Path) -> int:
    """Max mtime of series/ and immediate child dirs (new theme files bump child mtime)."""
    mtime_ns, _ = _fingerprint(series_dir)
    try:
        children = list(series_dir.iterdir())
    except OSError:
        return mtime_ns
    for child in children:
        if child.is_dir():
            try:
                child_mtime, _ = _fingerprint(child)
                mtime_ns = max(mtime_ns, child_mtime)
            except OSError:
                pass
    return mtime_ns


def list_theme_json_paths() -> list[Path]:
    """
    Scan data/series/**/*.json. Listing is cached against series/ + child-dir mtimes.
    New theme files appear on the next list after the containing folder mtime changes.
    """
    root = get_data_root()
    series_dir = root / "series"
    if not series_dir.is_dir():
        return []

    series_key = str(series_dir.resolve())
    try:
        fingerprint = _series_listing_fingerprint(series_dir)
    except OSError:
        return []

    cached = _listing_cache.get(series_key)
    if cached is not None and cached[0] == fingerprint:
        return [root / rel for rel in cached[1]]

    rels: list[str] = []
    for path in sorted(series_dir.rglob("*.json")):
        if path.is_file():
            rels.append(str(path.relative_to(root)))

    # Recompute after walk in case create raced; store current fingerprint.
    try:
        fingerprint = _series_listing_fingerprint(series_dir)
    except OSError:
        pass
    _listing_cache[series_key] = (fingerprint, rels)
    return [root / rel for rel in rels]


def list_theme_documents() -> list[dict[str, Any]]:
    """Load every theme JSON under series/ (mtime-cached per file)."""
    docs: list[dict[str, Any]] = []
    for path in list_theme_json_paths():
        data = load_json_file(path)
        if isinstance(data, dict):
            docs.append(data)
    return docs


def find_theme_document_by_code(theme_code: str) -> dict[str, Any] | None:
    code = theme_code.strip().upper()
    if not code:
        return None
    for doc in list_theme_documents():
        if str(doc.get("themeCode", "")).upper() == code:
            return doc
    return None


def find_design_by_internal_id(internal_id: str) -> dict[str, Any] | None:
    found = find_design_with_document(internal_id)
    return found[0] if found else None


def find_design_with_document(
    internal_id: str,
) -> tuple[dict[str, Any], dict[str, Any]] | None:
    needle = internal_id.strip()
    if not needle:
        return None
    for doc in list_theme_documents():
        designs = doc.get("designs")
        if not isinstance(designs, list):
            continue
        for design in designs:
            if isinstance(design, dict) and design.get("internalId") == needle:
                return design, doc
    return None
