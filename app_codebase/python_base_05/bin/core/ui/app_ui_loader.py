"""Mtime-fingerprint loader for app_ui.json — all screen UI configs SSOT.

Edit the JSON on disk; the next request picks up changes without an API restart.

Shape (per screen key)::

    {
      "museum": {
        "featuredSerials": [
          "ANM-…",
          {"serial": "ANM-…", "generationNumber": 1}
        ]
      }
    }

Add new screen blocks under the same file as needed.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from core.utils.dev_logger import customlog

LOGGING_SWITCH = True

# path_str -> (mtime_ns, size, normalized_doc)
_file_cache: dict[str, tuple[int, int, dict[str, Any]]] = {}
_data_root_override: Path | None = None

_EMPTY_MUSEUM: dict[str, Any] = {
    "featuredSerials": [],
}


def default_data_root() -> Path:
    return Path(__file__).resolve().parent / "data"


def get_data_root() -> Path:
    env = os.environ.get("APP_UI_DATA_ROOT", "").strip()
    if env:
        return Path(env).expanduser().resolve()
    if _data_root_override is not None:
        return _data_root_override
    return default_data_root()


def set_data_root_override(root: Path | None) -> None:
    global _data_root_override
    _data_root_override = root.resolve() if root is not None else None
    clear_caches()


def clear_caches() -> None:
    _file_cache.clear()


def app_ui_json_path() -> Path:
    return get_data_root() / "app_ui.json"


def _fingerprint(path: Path) -> tuple[int, int]:
    st = path.stat()
    mtime_ns = getattr(st, "st_mtime_ns", int(st.st_mtime * 1_000_000_000))
    return mtime_ns, st.st_size


def _optional_positive_int(raw: Any) -> int | None:
    if raw is None or raw == "":
        return None
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return None
    return value if value >= 1 else None


def _entry_from_parts(
    serial_raw: Any, *, generation_raw: Any = None
) -> dict[str, Any] | None:
    serial = str(serial_raw or "").strip()
    if not serial:
        return None
    return {
        "serial": serial,
        "generationNumber": _optional_positive_int(generation_raw),
    }


def _normalize_banner_entry(raw: Any) -> dict[str, Any] | None:
    if isinstance(raw, str):
        return _entry_from_parts(raw)
    if not isinstance(raw, dict):
        return None
    serial = (
        raw.get("serial")
        or raw.get("bannerSerial")
        or raw.get("banner_serial")
        or raw.get("designId")
        or raw.get("design_id")
        or ""
    )
    gen = (
        raw.get("generationNumber")
        if raw.get("generationNumber") is not None
        else raw.get("generation_number")
        if raw.get("generation_number") is not None
        else raw.get("bannerGenerationNumber")
        if raw.get("bannerGenerationNumber") is not None
        else raw.get("banner_generation_number")
    )
    return _entry_from_parts(serial, generation_raw=gen)


def _normalize_museum(raw: Any) -> dict[str, Any]:
    src = raw if isinstance(raw, dict) else {}
    banner = src.get("banner") if isinstance(src.get("banner"), dict) else {}

    entries: list[dict[str, Any]] = []
    seen: set[str] = set()

    def _add(entry: dict[str, Any] | None) -> None:
        if entry is None:
            return
        key = f"{entry['serial']}|{entry.get('generationNumber')}"
        if key in seen:
            return
        seen.add(key)
        entries.append(entry)

    for key in ("featuredSerials", "featured_serials", "bannerSerials", "banner_serials", "serials"):
        raw_list = src.get(key)
        if isinstance(raw_list, list):
            for item in raw_list:
                _add(_normalize_banner_entry(item))
            break

    banner_list = None
    if isinstance(banner, dict):
        banner_list = banner.get("serials") or banner.get("featuredSerials")
    if isinstance(banner_list, list) and not entries:
        for item in banner_list:
            _add(_normalize_banner_entry(item))

    # Back-compat: singular featured/banner serial
    if not entries:
        singular = (
            src.get("featuredSerial")
            or src.get("featured_serial")
            or src.get("bannerSerial")
            or src.get("banner_serial")
            or src.get("serial")
            or src.get("designId")
            or src.get("design_id")
            or banner.get("serial")
            or banner.get("designId")
            or banner.get("design_id")
            or ""
        )
        gen_raw = None
        for key in (
            "featuredGenerationNumber",
            "bannerGenerationNumber",
            "banner_generation_number",
            "generationNumber",
            "generation_number",
        ):
            if key in src and src.get(key) is not None:
                gen_raw = src.get(key)
                break
        if gen_raw is None:
            for key in ("generationNumber", "generation_number"):
                if key in banner and banner.get(key) is not None:
                    gen_raw = banner.get(key)
                    break
        _add(_entry_from_parts(singular, generation_raw=gen_raw))

    return {"featuredSerials": entries}


def _normalize_doc(raw: Any) -> dict[str, Any]:
    src = raw if isinstance(raw, dict) else {}
    # Back-compat: flat museum fields at root (pre multi-screen file).
    museum_raw = src.get("museum")
    if not isinstance(museum_raw, dict) and (
        src.get("featuredSerials")
        or src.get("bannerSerials")
        or src.get("bannerSerial")
        or src.get("featuredSerial")
        or src.get("serial")
        or src.get("designId")
        or isinstance(src.get("banner"), dict)
    ):
        museum_raw = src

    out: dict[str, Any] = {
        "museum": _normalize_museum(museum_raw),
    }
    # Pass through other screen blocks as plain dicts for future consumers.
    for key, value in src.items():
        if key == "museum" or key in out:
            continue
        if isinstance(value, dict):
            out[str(key)] = value
    return out


def _empty_doc() -> dict[str, Any]:
    return {"museum": dict(_EMPTY_MUSEUM)}


def load_app_ui() -> dict[str, Any]:
    """Return normalized multi-screen UI config; empty museum when missing/invalid."""
    path = app_ui_json_path()
    path_key = str(path)
    try:
        fp = _fingerprint(path)
    except OSError:
        if LOGGING_SWITCH:
            customlog(f"app_ui: missing path={path}")
        return _empty_doc()

    cached = _file_cache.get(path_key)
    if cached is not None and cached[0] == fp[0] and cached[1] == fp[1]:
        return cached[2]

    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        if LOGGING_SWITCH:
            customlog(f"app_ui: load failed path={path} err={exc}")
        doc = _empty_doc()
        _file_cache[path_key] = (fp[0], fp[1], doc)
        return doc

    doc = _normalize_doc(raw)
    _file_cache[path_key] = (fp[0], fp[1], doc)
    if LOGGING_SWITCH:
        museum = doc.get("museum") or {}
        serials = museum.get("featuredSerials") or []
        customlog(
            f"app_ui: loaded screens={sorted(doc.keys())} "
            f"museum.featuredSerials={len(serials)}"
        )
    return doc


def get_screen_ui(screen: str) -> dict[str, Any]:
    """Return one screen block from app_ui.json (mtime-cached)."""
    key = (screen or "").strip()
    doc = load_app_ui()
    block = doc.get(key)
    if isinstance(block, dict):
        return block
    if key == "museum":
        return dict(_EMPTY_MUSEUM)
    return {}
