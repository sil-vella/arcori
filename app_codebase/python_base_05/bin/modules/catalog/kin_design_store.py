"""Per-Kin catalog design files — one JSON per internalId (no shared category rewrite)."""

from __future__ import annotations

import json
import os
from typing import Any

from modules.catalog.catalog_ids import art_basename
from modules.user.upload_config import upload_root

# Disk: {UPLOAD_ROOT}/kin/designs/{stem}.json
# Public: /media/kin/designs/{stem}.json
# Stem prefers art_basename (no GENnnn) so Legacy echo ids still find pre-GEN files.
DESIGNS_SUBDIR = "kin/designs"
LOTTIE_SUBDIR = "kin/players"


def _media_stems(internal_id: str) -> list[str]:
    """Candidate filename stems: exact id, then GEN-stripped art basename."""
    raw = (internal_id or "").strip()
    if not raw:
        return []
    stems = [raw]
    base = art_basename(raw)
    if base and base != raw:
        stems.append(base)
    return stems


def _first_existing_stem(subdir: str, internal_id: str) -> str:
    """Pick stem whose file exists; else art_basename (stable write target)."""
    root = upload_root()
    for stem in _media_stems(internal_id):
        path = os.path.join(root, subdir, f"{stem}.json")
        if os.path.isfile(path):
            return stem
    return art_basename(internal_id) or (internal_id or "").strip()


def design_relative_path(internal_id: str) -> str:
    stem = _first_existing_stem(DESIGNS_SUBDIR, internal_id)
    return f"{DESIGNS_SUBDIR}/{stem}.json"


def lottie_relative_path(internal_id: str) -> str:
    stem = _first_existing_stem(LOTTIE_SUBDIR, internal_id)
    return f"{LOTTIE_SUBDIR}/{stem}.json"


def design_disk_path(internal_id: str) -> str:
    return os.path.join(upload_root(), design_relative_path(internal_id))


def lottie_disk_path(internal_id: str) -> str:
    return os.path.join(upload_root(), lottie_relative_path(internal_id))


def design_public_url(internal_id: str) -> str:
    return f"/media/{design_relative_path(internal_id)}"


def lottie_public_url(internal_id: str) -> str:
    return f"/media/{lottie_relative_path(internal_id)}"


def _write_stem(internal_id: str) -> str:
    """Always write under GEN-stripped basename so echoes share one media file."""
    return art_basename(internal_id) or (internal_id or "").strip()


def _atomic_write_json(disk_path: str, payload: dict[str, Any]) -> None:
    os.makedirs(os.path.dirname(disk_path), exist_ok=True)
    data = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
    temp_path = f"{disk_path}.tmp"
    with open(temp_path, "wb") as handle:
        handle.write(data)
    os.replace(temp_path, disk_path)


def write_design_file(internal_id: str, design: dict[str, Any]) -> str:
    """Write one design JSON file. Returns public path."""
    stem = _write_stem(internal_id)
    path = os.path.join(upload_root(), DESIGNS_SUBDIR, f"{stem}.json")
    _atomic_write_json(path, design)
    return f"/media/{DESIGNS_SUBDIR}/{stem}.json"


def write_lottie_file(internal_id: str, lottie: dict[str, Any]) -> str:
    """Write one Lottie JSON file. Returns public path."""
    stem = _write_stem(internal_id)
    path = os.path.join(upload_root(), LOTTIE_SUBDIR, f"{stem}.json")
    _atomic_write_json(path, lottie)
    return f"/media/{LOTTIE_SUBDIR}/{stem}.json"


def read_design_file(internal_id: str) -> dict[str, Any] | None:
    for stem in _media_stems(internal_id):
        path = os.path.join(upload_root(), DESIGNS_SUBDIR, f"{stem}.json")
        if not os.path.isfile(path):
            continue
        try:
            with open(path, encoding="utf-8") as handle:
                data = json.load(handle)
        except (OSError, json.JSONDecodeError):
            continue
        if isinstance(data, dict):
            return data
    return None


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
