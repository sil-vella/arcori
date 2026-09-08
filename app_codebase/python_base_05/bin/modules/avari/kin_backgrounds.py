"""Scan Kin background art under CATALOG_KIN_MEDIA_ROOT (hot-add without client rebuild)."""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any

from core.utils.dev_logger import customlog

LOGGING_SWITCH = True

# Filename: KIN_BG_{THEME}_{STYLE}_{NNN}.webp — theme/style tokens discovered at scan time.
_BG_FILE_RE = re.compile(
    r"^KIN_BG_([A-Za-z0-9]+)_([A-Za-z0-9_]+)_(\d+)\.webp$",
    re.IGNORECASE,
)

_PUBLIC_PREFIX = "/catalog-media/kin/gen001/00backgrounds"


def _title_from_token(token: str) -> str:
    parts = [p for p in (token or "").split("_") if p]
    return " ".join(p[:1].upper() + p[1:].lower() for p in parts)


def kin_media_root() -> Path:
    raw = os.environ.get("CATALOG_KIN_MEDIA_ROOT", "").strip()
    if raw:
        return Path(raw)
    # Local / test fallback relative to repo assets (compose uses /data/catalog-kin).
    return Path("/data/catalog-kin")


def backgrounds_dir() -> Path:
    return kin_media_root() / "gen001" / "00backgrounds"


def parse_background_filename(name: str) -> dict[str, Any] | None:
    """Parse `KIN_BG_{THEME}_{STYLE}_{NNN}.webp` → catalog fields."""
    base = (name or "").strip()
    m = _BG_FILE_RE.match(base)
    if not m:
        return None
    theme = m.group(1).upper()
    style = m.group(2).upper()
    seq = m.group(3)
    stem = base[: -len(".webp")] if base.lower().endswith(".webp") else base
    return {
        "id": stem,
        "fileName": base,
        "theme": theme,
        "style": style,
        "seq": seq,
        "displayName": f"{_title_from_token(theme)} · {_title_from_token(style)}",
        "imageUrl": f"{_PUBLIC_PREFIX}/{base}",
    }


def list_kin_backgrounds() -> dict[str, Any]:
    """Return scanned backgrounds + derived theme/style indexes."""
    root = backgrounds_dir()
    items: list[dict[str, Any]] = []
    if not root.is_dir():
        if LOGGING_SWITCH:
            customlog(f"avari: kin backgrounds dir missing {root}")
        return {"backgrounds": [], "themes": [], "stylesByTheme": {}}

    for path in sorted(root.iterdir()):
        if not path.is_file():
            continue
        if path.name.startswith("."):
            continue
        if path.suffix.lower() != ".webp":
            continue
        parsed = parse_background_filename(path.name)
        if parsed is None:
            if LOGGING_SWITCH:
                customlog(f"avari: skip unrecognized kin bg {path.name}")
            continue
        items.append(parsed)

    themes: list[str] = []
    styles_by_theme: dict[str, list[str]] = {}
    for row in items:
        theme = str(row["theme"])
        style = str(row["style"])
        if theme not in themes:
            themes.append(theme)
        bucket = styles_by_theme.setdefault(theme, [])
        if style not in bucket:
            bucket.append(style)
    for styles in styles_by_theme.values():
        styles.sort()

    if LOGGING_SWITCH:
        customlog(f"avari: kin backgrounds listed n={len(items)} dir={root}")

    return {
        "backgrounds": items,
        "themes": themes,
        "stylesByTheme": styles_by_theme,
    }
