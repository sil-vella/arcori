"""Mtime-fingerprint loader for daily_goals.json SSOT."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Any

from core.notifications.screen_names import is_known_screen
from core.utils.dev_logger import customlog
from core.utils.media_fields import normalize_media_map
from modules.daily_goals.daily_goals_types import (
    CADENCE_DAILY,
    CADENCES,
    CONTINUE_CURRENCY_GOLD_ARCORI,
    ON_MISS_RESET_TO_ZERO,
    POST_ACTION_MOVE_TO_SCREEN,
    POST_ACTION_NONE,
    POST_ACTION_OPEN_PATH,
    POST_COMPLETE_ACTION_TYPES,
    SECTION_DAILY_GOALS,
    SECTION_TASKS,
    SECTIONS,
    TASK_TYPE_CLAIM_GATE,
    TASK_TYPES,
    VALUE_KIND_STREAK,
)

LOGGING_SWITCH = True

# path_str -> (mtime_ns, size, normalized_doc, revision)
_file_cache: dict[str, tuple[int, int, dict[str, Any], str]] = {}
_data_root_override: Path | None = None


def default_data_root() -> Path:
    return Path(__file__).resolve().parent / "data"


def get_data_root() -> Path:
    env = os.environ.get("DAILY_GOALS_DATA_ROOT", "").strip()
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


def daily_goals_json_path() -> Path:
    return get_data_root() / "daily_goals.json"


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
    if action_type not in POST_COMPLETE_ACTION_TYPES:
        return None
    if action_type == POST_ACTION_NONE:
        return {"type": POST_ACTION_NONE}
    if action_type == POST_ACTION_MOVE_TO_SCREEN:
        screen = str(raw.get("screen") or "").strip()
        if not screen:
            return None
        if not is_known_screen(screen) and LOGGING_SWITCH:
            customlog(
                f"daily_goals: post_complete_action screen not registered yet: {screen}"
            )
        cta = str(raw.get("cta_label") or raw.get("ctaLabel") or "Continue").strip()
        return {
            "type": POST_ACTION_MOVE_TO_SCREEN,
            "screen": screen,
            "cta_label": cta or "Continue",
        }
    to_path = str(raw.get("to_path") or raw.get("toPath") or "").strip()
    if not to_path:
        return None
    cta = str(raw.get("cta_label") or raw.get("ctaLabel") or "Continue").strip()
    return {
        "type": POST_ACTION_OPEN_PATH,
        "to_path": to_path,
        "cta_label": cta or "Continue",
    }


def _normalize_value(raw: Any) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        raw = {}
    kind = str(raw.get("kind") or VALUE_KIND_STREAK).strip().lower()
    if kind != VALUE_KIND_STREAK:
        return None
    try:
        delta = max(0, int(raw.get("on_complete_delta", raw.get("onCompleteDelta", 1))))
    except (TypeError, ValueError):
        return None
    on_miss = str(
        raw.get("on_miss") or raw.get("onMiss") or ON_MISS_RESET_TO_ZERO
    ).strip().lower()
    if on_miss != ON_MISS_RESET_TO_ZERO:
        return None
    return {
        "kind": VALUE_KIND_STREAK,
        "on_complete_delta": delta,
        "on_miss": ON_MISS_RESET_TO_ZERO,
    }


def _normalize_continue(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, dict):
        return {"enabled": False, "currency": CONTINUE_CURRENCY_GOLD_ARCORI, "cost": 0}
    enabled = bool(raw.get("enabled", False))
    currency = str(raw.get("currency") or CONTINUE_CURRENCY_GOLD_ARCORI).strip().lower()
    if currency != CONTINUE_CURRENCY_GOLD_ARCORI:
        currency = CONTINUE_CURRENCY_GOLD_ARCORI
    try:
        cost = max(0, int(raw.get("cost", 0)))
    except (TypeError, ValueError):
        cost = 0
    return {"enabled": enabled, "currency": currency, "cost": cost}


def _normalize_reward(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, dict):
        return {"kind": "deferred", "placeholder": True}
    kind = str(raw.get("kind") or "deferred").strip().lower() or "deferred"
    out: dict[str, Any] = {"kind": kind}
    if "placeholder" in raw:
        out["placeholder"] = bool(raw.get("placeholder"))
    if "table_id" in raw or "tableId" in raw:
        tid = raw.get("table_id", raw.get("tableId"))
        out["table_id"] = None if tid is None else str(tid)
    return out


def _normalize_entry(raw: dict[str, Any]) -> dict[str, Any] | None:
    goal_id = str(raw.get("id") or "").strip()
    if not goal_id:
        return None
    name = str(raw.get("name") or goal_id).strip()
    desc = str(raw.get("description") or "").strip()
    cadence = str(raw.get("cadence") or CADENCE_DAILY).strip().lower()
    if cadence not in CADENCES:
        if LOGGING_SWITCH:
            customlog(f"daily_goals: skip bad cadence id={goal_id} cadence={cadence}")
        return None
    featured = bool(raw.get("featured", False))
    section_raw = str(raw.get("section") or "").strip().lower()
    if section_raw in SECTIONS:
        section = section_raw
    else:
        # Default: featured missions → Daily Goals; everything else → Tasks.
        section = SECTION_DAILY_GOALS if featured else SECTION_TASKS
    task_type = str(raw.get("task_type") or raw.get("taskType") or "").strip().lower()
    if task_type not in TASK_TYPES:
        if LOGGING_SWITCH:
            customlog(f"daily_goals: skip unknown task_type id={goal_id} type={task_type}")
        return None
    params = _normalize_params(raw.get("params"))
    if task_type in (
        "matches_completed",
        "flips_completed",
        "wins_completed",
        "login",
    ):
        try:
            vmin = max(1, int(params.get("min", 1)))
        except (TypeError, ValueError):
            if LOGGING_SWITCH:
                customlog(f"daily_goals: skip bad min id={goal_id}")
            return None
        params = dict(params)
        params["min"] = vmin
    elif task_type == TASK_TYPE_CLAIM_GATE:
        req = params.get("requires_goal_ids") or params.get("requiresGoalIds") or []
        if not isinstance(req, list):
            req = []
        ids = [str(x).strip() for x in req if str(x).strip()]
        params = {"requires_goal_ids": ids}
        if "min_featured_complete" in params or "minFeaturedComplete" in raw.get(
            "params", {}
        ):
            pass

    value = _normalize_value(raw.get("value"))
    if value is None:
        if LOGGING_SWITCH:
            customlog(f"daily_goals: skip bad value id={goal_id}")
        return None
    continue_cfg = _normalize_continue(raw.get("continue"))
    reward = _normalize_reward(raw.get("reward"))
    media = normalize_media_map(raw.get("media"))
    action = _normalize_post_action(
        raw.get("post_complete_action") or raw.get("postCompleteAction")
    )
    if action is None:
        if LOGGING_SWITCH:
            customlog(f"daily_goals: skip bad post_complete_action id={goal_id}")
        return None

    return {
        "id": goal_id,
        "name": name or goal_id,
        "description": desc,
        "cadence": cadence,
        "featured": featured,
        "section": section,
        "task_type": task_type,
        "params": params,
        "value": value,
        "continue": continue_cfg,
        "reward": reward,
        "media": media,
        "post_complete_action": action,
    }


def _normalize_document(doc: dict[str, Any]) -> dict[str, Any]:
    try:
        schema_version = int(doc.get("schema_version") or doc.get("schemaVersion") or 1)
    except (TypeError, ValueError):
        schema_version = 1
    day_boundary = str(doc.get("day_boundary") or doc.get("dayBoundary") or "utc").strip().lower()
    if day_boundary != "utc":
        day_boundary = "utc"
    raw_list = doc.get("goals")
    goals: list[dict[str, Any]] = []
    seen: set[str] = set()
    if isinstance(raw_list, list):
        for item in raw_list:
            if not isinstance(item, dict):
                continue
            norm = _normalize_entry(item)
            if norm is None:
                continue
            gid = norm["id"]
            if gid in seen:
                continue
            seen.add(gid)
            goals.append(norm)
    return {
        "schema_version": schema_version,
        "day_boundary": day_boundary,
        "goals": goals,
    }


def load_daily_goals_document() -> tuple[dict[str, Any], str]:
    path = daily_goals_json_path()
    resolved = path.resolve()
    key = str(resolved)
    if not resolved.is_file():
        empty = {"schema_version": 1, "day_boundary": "utc", "goals": []}
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
            f"daily_goals: loaded count={len(normalized['goals'])} rev={revision[:12]}"
        )
    return normalized, revision


def list_goals() -> list[dict[str, Any]]:
    doc, _ = load_daily_goals_document()
    return list(doc.get("goals") or [])


def goal_by_id(goal_id: str) -> dict[str, Any] | None:
    gid = (goal_id or "").strip()
    if not gid:
        return None
    for row in list_goals():
        if row.get("id") == gid:
            return dict(row)
    return None


def catalog_revision() -> str:
    _, rev = load_daily_goals_document()
    return rev


def featured_goal_ids() -> list[str]:
    return [str(g["id"]) for g in list_goals() if g.get("featured")]
