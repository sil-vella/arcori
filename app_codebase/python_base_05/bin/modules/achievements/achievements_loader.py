"""Mtime-fingerprint loader for achievements.json SSOT."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Any

from core.notifications.screen_names import is_known_screen
from core.utils.dev_logger import customlog
from core.utils.media_fields import normalize_media_map
from modules.achievements.achievements_types import (
    ACHIEVEMENT_TYPES,
    POST_ACHIEVE_ACTION_TYPES,
    POST_ACTION_MOVE_TO_SCREEN,
    POST_ACTION_NONE,
    POST_ACTION_OPEN_PATH,
)

LOGGING_SWITCH = True

# path_str -> (mtime_ns, size, normalized_doc, revision)
_file_cache: dict[str, tuple[int, int, dict[str, Any], str]] = {}
_data_root_override: Path | None = None


def default_data_root() -> Path:
    return Path(__file__).resolve().parent / "data"


def get_data_root() -> Path:
    env = os.environ.get("ACHIEVEMENTS_DATA_ROOT", "").strip()
    if env:
        return Path(env).expanduser().resolve()
    if _data_root_override is not None:
        return _data_root_override
    return default_data_root()


def set_data_root_override(root: Path | None) -> None:
    """Test helper: pin achievements root (None clears). Also clears caches."""
    global _data_root_override
    _data_root_override = root.resolve() if root is not None else None
    clear_caches()


def clear_caches() -> None:
    _file_cache.clear()


def achievements_json_path() -> Path:
    return get_data_root() / "achievements.json"


def _fingerprint(path: Path) -> tuple[int, int]:
    st = path.stat()
    mtime_ns = getattr(st, "st_mtime_ns", int(st.st_mtime * 1_000_000_000))
    return mtime_ns, st.st_size


def _compute_revision(canonical: dict[str, Any]) -> str:
    blob = json.dumps(canonical, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(blob).hexdigest()


def _normalize_params(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, dict):
        return {}
    out: dict[str, Any] = {}
    for key, value in raw.items():
        k = str(key).strip()
        if not k:
            continue
        out[k] = value
    return out


def _normalize_post_action(raw: Any) -> dict[str, Any] | None:
    if raw is None:
        return {"type": POST_ACTION_NONE}
    if not isinstance(raw, dict):
        return None
    action_type = str(raw.get("type") or "").strip().lower()
    if action_type not in POST_ACHIEVE_ACTION_TYPES:
        return None
    if action_type == POST_ACTION_NONE:
        return {"type": POST_ACTION_NONE}
    if action_type == POST_ACTION_MOVE_TO_SCREEN:
        screen = str(raw.get("screen") or "").strip()
        if not screen:
            return None
        # Soft-validate: unknown screens keep the row but clients no-op safely.
        if not is_known_screen(screen) and LOGGING_SWITCH:
            customlog(
                f"achievements: post_achieve_action screen not registered yet: {screen}"
            )
        cta = str(raw.get("cta_label") or raw.get("ctaLabel") or "Continue").strip()
        return {
            "type": POST_ACTION_MOVE_TO_SCREEN,
            "screen": screen,
            "cta_label": cta or "Continue",
        }
    # open_path
    to_path = str(raw.get("to_path") or raw.get("toPath") or "").strip()
    if not to_path:
        return None
    cta = str(raw.get("cta_label") or raw.get("ctaLabel") or "Continue").strip()
    return {
        "type": POST_ACTION_OPEN_PATH,
        "to_path": to_path,
        "cta_label": cta or "Continue",
    }


def _normalize_entry(raw: dict[str, Any]) -> dict[str, Any] | None:
    ach_id = str(raw.get("id") or "").strip()
    if not ach_id:
        return None
    name = str(raw.get("achievement_name") or raw.get("achievementName") or ach_id).strip()
    desc = str(raw.get("description") or "").strip()
    atype = str(raw.get("achievement_type") or raw.get("achievementType") or "").strip().lower()
    if atype not in ACHIEVEMENT_TYPES:
        if LOGGING_SWITCH:
            customlog(f"achievements: skip unknown type id={ach_id} type={atype}")
        return None
    params = _normalize_params(raw.get("params"))
    # Type-specific required params
    if atype in (
        "total_wins",
        "total_matches",
        "total_flips",
        "win_streak",
        "mastery_points",
        "event_flips",
    ):
        try:
            vmin = max(1, int(params.get("min")))
        except (TypeError, ValueError):
            if LOGGING_SWITCH:
                customlog(f"achievements: skip bad min id={ach_id}")
            return None
        params = dict(params)
        params["min"] = vmin
        if atype == "mastery_points":
            design_id = str(params.get("design_id") or params.get("designId") or "").strip()
            if design_id:
                params["design_id"] = design_id
            else:
                params.pop("design_id", None)
                params.pop("designId", None)
        if atype == "event_flips":
            event_id = str(params.get("event_id") or params.get("eventId") or "").strip()
            if not event_id:
                if LOGGING_SWITCH:
                    customlog(f"achievements: skip event_flips without event_id id={ach_id}")
                return None
            params["event_id"] = event_id
            params.pop("eventId", None)
    elif atype == "event_arcori_cleared":
        event_id = str(params.get("event_id") or params.get("eventId") or "").strip()
        if not event_id:
            if LOGGING_SWITCH:
                customlog(
                    f"achievements: skip event_arcori_cleared without event_id id={ach_id}"
                )
            return None
        design_raw = params.get("design_ids") or params.get("designIds") or []
        design_ids: list[str] = []
        if isinstance(design_raw, list):
            seen: set[str] = set()
            for item in design_raw:
                did = str(item or "").strip()
                if not did or did in seen:
                    continue
                seen.add(did)
                design_ids.append(did)
        params = {"event_id": event_id}
        if design_ids:
            params["design_ids"] = design_ids
    elif atype == "match_flag":
        flag = str(params.get("flag") or "").strip().lower()
        if not flag:
            if LOGGING_SWITCH:
                customlog(f"achievements: skip match_flag without flag id={ach_id}")
            return None
        requires_win = params.get("requires_win", True)
        if not isinstance(requires_win, bool):
            requires_win = True
        params = {"flag": flag, "requires_win": requires_win}

    action = _normalize_post_action(raw.get("post_achieve_action") or raw.get("postAchieveAction"))
    if action is None:
        if LOGGING_SWITCH:
            customlog(f"achievements: skip bad post_achieve_action id={ach_id}")
        return None

    media = normalize_media_map(raw.get("media"))

    return {
        "id": ach_id,
        "achievement_name": name or ach_id,
        "description": desc,
        "achievement_type": atype,
        "params": params,
        "media": media,
        "post_achieve_action": action,
    }


def _normalize_document(doc: dict[str, Any]) -> dict[str, Any]:
    try:
        schema_version = int(doc.get("schema_version") or doc.get("schemaVersion") or 1)
    except (TypeError, ValueError):
        schema_version = 1
    raw_list = doc.get("achievements")
    achievements: list[dict[str, Any]] = []
    seen: set[str] = set()
    if isinstance(raw_list, list):
        for item in raw_list:
            if not isinstance(item, dict):
                continue
            norm = _normalize_entry(item)
            if norm is None:
                continue
            aid = norm["id"]
            if aid in seen:
                continue
            seen.add(aid)
            achievements.append(norm)
    return {"schema_version": schema_version, "achievements": achievements}


def load_achievements_document() -> tuple[dict[str, Any], str]:
    """Return (normalized_doc, revision). Hot-reloads when file mtime/size changes."""
    path = achievements_json_path()
    resolved = path.resolve()
    key = str(resolved)
    if not resolved.is_file():
        empty = {"schema_version": 1, "achievements": []}
        return empty, _compute_revision(empty)

    mtime_ns, size = _fingerprint(resolved)
    cached = _file_cache.get(key)
    if cached is not None and cached[0] == mtime_ns and cached[1] == size:
        return cached[2], cached[3]

    with resolved.open("r", encoding="utf-8") as fh:
        raw = json.load(fh)
    if not isinstance(raw, dict):
        raw = {}
    normalized = _normalize_document(raw)
    revision = _compute_revision(normalized)
    _file_cache[key] = (mtime_ns, size, normalized, revision)
    if LOGGING_SWITCH:
        customlog(
            f"achievements: loaded count={len(normalized['achievements'])} "
            f"rev={revision[:12]}"
        )
    return normalized, revision


def list_achievements() -> list[dict[str, Any]]:
    doc, _ = load_achievements_document()
    return list(doc.get("achievements") or [])


def achievement_by_id(ach_id: str) -> dict[str, Any] | None:
    aid = (ach_id or "").strip()
    if not aid:
        return None
    for row in list_achievements():
        if row.get("id") == aid:
            return dict(row)
    return None


def catalog_revision() -> str:
    _, rev = load_achievements_document()
    return rev
