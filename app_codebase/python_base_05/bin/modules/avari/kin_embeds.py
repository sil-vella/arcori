"""Kin addition embeds under CATALOG_KIN_MEDIA_ROOT (hot-add without client rebuild).

Reads ``ser001/00embeds/embeds.json`` on each list call (no process restart).
PNG paths are relative to that folder; public URLs use ``/catalog-media/kin/...``.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from core.utils.dev_logger import customlog

LOGGING_SWITCH = True

_PUBLIC_PREFIX = "/catalog-media/kin/ser001/00embeds"
_CATALOG_NAME = "embeds.json"


def kin_media_root() -> Path:
    raw = os.environ.get("CATALOG_KIN_MEDIA_ROOT", "").strip()
    if raw:
        return Path(raw)
    return Path("/data/catalog-kin")


def embeds_dir() -> Path:
    return kin_media_root() / "ser001" / "00embeds"


def _placement_ok(raw: Any) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        return None
    in_front = str(raw.get("inFrontOf") or "").strip()
    behind = str(raw.get("behindLayer") or "").strip()
    if bool(in_front) == bool(behind):
        return None
    out: dict[str, Any] = {}
    if in_front:
        out["inFrontOf"] = in_front
    else:
        out["behindLayer"] = behind
    for key in ("p", "s"):
        val = raw.get(key)
        if isinstance(val, list) and val:
            out[key] = val
    return out


def _parse_attachment(raw: Any) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        return None
    kin_serial = str(raw.get("kinSerial") or "").strip()
    part_serial = str(raw.get("partSerial") or "").strip()
    placement = _placement_ok(raw.get("placement"))
    if not kin_serial or not part_serial or placement is None:
        return None
    return {
        "kinSerial": kin_serial,
        "partSerial": part_serial,
        "placement": placement,
    }


def _parse_embed_row(raw: Any, root: Path) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        return None
    serial = str(raw.get("serial") or "").strip()
    if not serial:
        return None
    file_name = str(raw.get("fileName") or "").strip().lstrip("/")
    if not file_name or ".." in file_name.split("/"):
        return None
    path = root / file_name
    if not path.is_file():
        if LOGGING_SWITCH:
            customlog(f"avari: kin embed missing file serial={serial} path={path}")
        return None
    display = str(raw.get("displayName") or "").strip() or serial
    attachments: list[dict[str, Any]] = []
    raw_atts = raw.get("attachments")
    if isinstance(raw_atts, list):
        for item in raw_atts:
            parsed = _parse_attachment(item)
            if parsed is not None:
                attachments.append(parsed)
    if not attachments:
        if LOGGING_SWITCH:
            customlog(f"avari: kin embed skip (no attachments) serial={serial}")
        return None
    return {
        "serial": serial,
        "displayName": display,
        "fileName": file_name,
        "imageUrl": f"{_PUBLIC_PREFIX}/{file_name}",
        "attachments": attachments,
    }


def list_kin_embeds() -> dict[str, Any]:
    """Return embeds + attachment specs from host catalog JSON."""
    root = embeds_dir()
    catalog_path = root / _CATALOG_NAME
    if not catalog_path.is_file():
        if LOGGING_SWITCH:
            customlog(f"avari: kin embeds catalog missing {catalog_path}")
        return {"embeds": []}

    try:
        raw = json.loads(catalog_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        if LOGGING_SWITCH:
            customlog(f"avari: kin embeds catalog read failed {exc}")
        return {"embeds": []}

    rows_in = raw.get("embeds") if isinstance(raw, dict) else None
    if not isinstance(rows_in, list):
        return {"embeds": []}

    items: list[dict[str, Any]] = []
    for row in rows_in:
        parsed = _parse_embed_row(row, root)
        if parsed is not None:
            items.append(parsed)

    if LOGGING_SWITCH:
        customlog(f"avari: kin embeds listed n={len(items)} dir={root}")

    return {"embeds": items}
