"""Per-Kin catalog design files — one JSON per internalId (no shared category rewrite)."""

from __future__ import annotations

import json
import os
from typing import Any

from modules.user.upload_config import upload_root

# Disk: {UPLOAD_ROOT}/kin/designs/{internalId}.json
# Public: /media/kin/designs/{internalId}.json (optional direct fetch)
DESIGNS_SUBDIR = "kin/designs"
LOTTIE_SUBDIR = "kin/players"


def design_relative_path(internal_id: str) -> str:
    return f"{DESIGNS_SUBDIR}/{internal_id.strip()}.json"


def lottie_relative_path(internal_id: str) -> str:
    return f"{LOTTIE_SUBDIR}/{internal_id.strip()}.json"


def design_disk_path(internal_id: str) -> str:
    return os.path.join(upload_root(), design_relative_path(internal_id))


def lottie_disk_path(internal_id: str) -> str:
    return os.path.join(upload_root(), lottie_relative_path(internal_id))


def design_public_url(internal_id: str) -> str:
    return f"/media/{design_relative_path(internal_id)}"


def lottie_public_url(internal_id: str) -> str:
    return f"/media/{lottie_relative_path(internal_id)}"


def _atomic_write_json(disk_path: str, payload: dict[str, Any]) -> None:
    os.makedirs(os.path.dirname(disk_path), exist_ok=True)
    data = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
    temp_path = f"{disk_path}.tmp"
    with open(temp_path, "wb") as handle:
        handle.write(data)
    os.replace(temp_path, disk_path)


def write_design_file(internal_id: str, design: dict[str, Any]) -> str:
    """Write one design JSON file. Returns public path."""
    path = design_disk_path(internal_id)
    _atomic_write_json(path, design)
    return design_public_url(internal_id)


def write_lottie_file(internal_id: str, lottie: dict[str, Any]) -> str:
    """Write one Lottie JSON file. Returns public path."""
    path = lottie_disk_path(internal_id)
    _atomic_write_json(path, lottie)
    return lottie_public_url(internal_id)


def read_design_file(internal_id: str) -> dict[str, Any] | None:
    path = design_disk_path(internal_id)
    if not os.path.isfile(path):
        return None
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def list_design_files() -> list[dict[str, Any]]:
    """Load every per-Kin design JSON under kin/designs/ (independent files)."""
    root = os.path.join(upload_root(), DESIGNS_SUBDIR)
    if not os.path.isdir(root):
        return []
    out: list[dict[str, Any]] = []
    try:
        names = sorted(os.listdir(root))
    except OSError:
        return []
    for name in names:
        if not name.endswith(".json") or name.endswith(".tmp"):
            continue
        path = os.path.join(root, name)
        if not os.path.isfile(path):
            continue
        try:
            with open(path, encoding="utf-8") as handle:
                data = json.load(handle)
        except (OSError, json.JSONDecodeError):
            continue
        if isinstance(data, dict) and data.get("internalId"):
            out.append(data)
    return out
