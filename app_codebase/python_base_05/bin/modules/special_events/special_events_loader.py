"""Special events JSON SSOT (mtime hot-reload) — full match-rules + media."""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

from core.utils.dev_logger import customlog
from core.utils.media_fields import media_for_client, normalize_media_map
from modules.special_events.special_events_types import (
    ARCORI_SOURCES,
    ARENA_MODE_FIXED_ARENA,
    ARENA_MODE_FIXED_REGION,
    ARENA_MODES,
    MATCH_CREDIT_FLIPS_MIN,
    MATCH_CREDITS,
    QUEUE_MODES,
    SLAMMER_MODE_ANY,
    SLAMMER_MODE_DESIGN_IDS,
    SLAMMER_MODE_TYPES,
    SLAMMER_MODES,
    ARCORI_SOURCE_CIRCULATION,
    ARENA_MODE_SEATED_REGIONS,
    MATCH_CREDIT_ANY_FINISH,
    QUEUE_MODE_OPEN,
)

LOGGING_SWITCH = True

_DATA_ROOT: Path | None = None
_CACHE_DOC: dict[str, Any] | None = None
_CACHE_MTIME: float | None = None
_CACHE_REVISION: str = ""
_BY_ID: dict[str, dict[str, Any]] = {}


def set_data_root_override(path: Path | None) -> None:
    global _DATA_ROOT
    _DATA_ROOT = path
    clear_caches()


def clear_caches() -> None:
    global _CACHE_DOC, _CACHE_MTIME, _CACHE_REVISION, _BY_ID
    _CACHE_DOC = None
    _CACHE_MTIME = None
    _CACHE_REVISION = ""
    _BY_ID = {}


def _default_data_path() -> Path:
    if _DATA_ROOT is not None:
        return _DATA_ROOT / "special_events.json"
    return Path(__file__).resolve().parent / "data" / "special_events.json"


def _str_list(raw: Any) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    if not isinstance(raw, list):
        return out
    for item in raw:
        s = str(item or "").strip()
        if not s or s in seen:
            continue
        seen.add(s)
        out.append(s)
    return out


def _int_list(raw: Any) -> list[int]:
    out: list[int] = []
    if not isinstance(raw, list):
        return out
    for item in raw:
        try:
            out.append(int(item))
        except (TypeError, ValueError):
            continue
    return out


def _clamp_int(raw: Any, *, default: int, min_v: int = 0, max_v: int = 99) -> int:
    try:
        v = int(raw)
    except (TypeError, ValueError):
        return default
    return max(min_v, min(max_v, v))


def _normalize_matchmaking(raw: Any) -> dict[str, Any]:
    src = raw if isinstance(raw, dict) else {}
    queue = str(src.get("queue_mode") or src.get("queueMode") or QUEUE_MODE_OPEN).strip()
    if queue not in QUEUE_MODES:
        queue = QUEUE_MODE_OPEN
    return {
        "players": _clamp_int(
            src.get("players") if src.get("players") is not None else src.get("targetSeats"),
            default=3,
            min_v=2,
            max_v=8,
        ),
        "ai_fill": src.get("ai_fill", src.get("aiFill", True)) is not False,
        "fill_window_sec": _clamp_int(
            src.get("fill_window_sec")
            if src.get("fill_window_sec") is not None
            else src.get("fillWindowSec"),
            default=5,
            min_v=1,
            max_v=120,
        ),
        "queue_mode": queue,
    }


def _normalize_match(raw: Any) -> dict[str, Any]:
    src = raw if isinstance(raw, dict) else {}
    fee_raw = src.get("fee_fragments")
    if fee_raw is None:
        fee_raw = src.get("feeFragments")
    fee: int | None
    if fee_raw is None:
        fee = None
    else:
        try:
            fee = max(0, int(fee_raw))
        except (TypeError, ValueError):
            fee = None
    return {
        "rounds": _clamp_int(
            src.get("rounds") if src.get("rounds") is not None else src.get("roundsTotal"),
            default=2,
            min_v=1,
            max_v=10,
        ),
        "fee_fragments": fee,
    }


def _normalize_matches(raw: Any) -> dict[str, Any]:
    src = raw if isinstance(raw, dict) else {}
    credit = str(src.get("credit") or MATCH_CREDIT_ANY_FINISH).strip().lower()
    if credit not in MATCH_CREDITS:
        credit = MATCH_CREDIT_ANY_FINISH
    params_raw = src.get("credit_params") or src.get("creditParams") or {}
    params: dict[str, Any] = {}
    if isinstance(params_raw, dict):
        if credit == MATCH_CREDIT_FLIPS_MIN:
            params["min"] = _clamp_int(params_raw.get("min"), default=1, min_v=1, max_v=999)
    return {
        "required": _clamp_int(src.get("required"), default=1, min_v=1, max_v=99),
        "credit": credit,
        "credit_params": params,
    }


def _normalize_slammer(raw: Any) -> dict[str, Any]:
    src = raw if isinstance(raw, dict) else {}
    mode = str(src.get("mode") or SLAMMER_MODE_ANY).strip().lower()
    if mode not in SLAMMER_MODES:
        mode = SLAMMER_MODE_ANY
    design_ids = _str_list(src.get("design_ids") or src.get("designIds"))
    types = _str_list(src.get("types"))
    if mode == SLAMMER_MODE_DESIGN_IDS and not design_ids:
        mode = SLAMMER_MODE_ANY
    if mode == SLAMMER_MODE_TYPES and not types:
        mode = SLAMMER_MODE_ANY
    return {"mode": mode, "design_ids": design_ids, "types": types}


def _normalize_eligibility(raw: Any) -> dict[str, Any]:
    src = raw if isinstance(raw, dict) else {}
    min_mv = src.get("min_mastery_value")
    if min_mv is None:
        min_mv = src.get("minMasteryValue")
    max_mv = src.get("max_mastery_value")
    if max_mv is None:
        max_mv = src.get("maxMasteryValue")
    try:
        min_v = float(min_mv) if min_mv is not None else 0.0
    except (TypeError, ValueError):
        min_v = 0.0
    max_v: float | None
    try:
        max_v = float(max_mv) if max_mv is not None else None
    except (TypeError, ValueError):
        max_v = None
    return {
        "min_mastery_value": max(0.0, min_v),
        "max_mastery_value": max_v,
        "required_titles": _str_list(
            src.get("required_titles") or src.get("requiredTitles")
        ),
        "required_slammer": _normalize_slammer(
            src.get("required_slammer") or src.get("requiredSlammer")
        ),
    }


def _normalize_arcori(raw: Any, legacy_design_ids: list[str]) -> dict[str, Any]:
    src = raw if isinstance(raw, dict) else {}
    source = str(src.get("source") or ARCORI_SOURCE_CIRCULATION).strip().lower()
    if source not in ARCORI_SOURCES:
        source = ARCORI_SOURCE_CIRCULATION
    design_ids = _str_list(src.get("design_ids") or src.get("designIds"))
    if not design_ids:
        design_ids = list(legacy_design_ids)
    return {
        "per_player": _clamp_int(
            src.get("per_player") if src.get("per_player") is not None else src.get("perPlayer"),
            default=1,
            min_v=1,
            max_v=3,
        ),
        "source": source,
        "series_ids": _str_list(src.get("series_ids") or src.get("seriesIds")),
        "generation_numbers": _int_list(
            src.get("generation_numbers") or src.get("generationNumbers")
        ),
        "region_codes": _str_list(src.get("region_codes") or src.get("regionCodes")),
        "design_ids": design_ids,
    }


def _normalize_arena(raw: Any) -> dict[str, Any]:
    src = raw if isinstance(raw, dict) else {}
    mode = str(src.get("mode") or ARENA_MODE_SEATED_REGIONS).strip().lower()
    if mode not in ARENA_MODES:
        mode = ARENA_MODE_SEATED_REGIONS
    region = str(src.get("region_code") or src.get("regionCode") or "").strip()
    arena_id = str(src.get("arena_id") or src.get("arenaId") or "").strip()
    if mode == ARENA_MODE_FIXED_ARENA and not arena_id:
        mode = ARENA_MODE_SEATED_REGIONS
    if mode == ARENA_MODE_FIXED_REGION and not region:
        mode = ARENA_MODE_SEATED_REGIONS
    return {
        "mode": mode,
        "region_code": region or None,
        "arena_id": arena_id or None,
    }


def _normalize_schedule(raw: Any) -> dict[str, Any]:
    src = raw if isinstance(raw, dict) else {}
    starts = src.get("startsAt") if "startsAt" in src else src.get("starts_at")
    ends = src.get("endsAt") if "endsAt" in src else src.get("ends_at")
    return {
        "starts_at": str(starts).strip() if starts else None,
        "ends_at": str(ends).strip() if ends else None,
    }


def _normalize_event(raw: dict[str, Any]) -> dict[str, Any] | None:
    eid = str(raw.get("id") or "").strip()
    if not eid:
        return None

    legacy_design = _str_list(raw.get("design_ids") or raw.get("designIds") or [])
    hooks_raw = raw.get("achievement_hooks") or raw.get("achievementHooks") or {}
    hooks_design: list[str] = []
    if isinstance(hooks_raw, dict):
        hooks_design = _str_list(
            hooks_raw.get("roster_design_ids") or hooks_raw.get("rosterDesignIds")
        )
    if not hooks_design:
        hooks_design = list(legacy_design)

    arcori = _normalize_arcori(raw.get("arcori"), legacy_design)
    # Public design_ids alias = achievement roster (hooks) or arcori.design_ids
    design_ids = hooks_design or list(arcori.get("design_ids") or [])

    media_norm = normalize_media_map(raw.get("media") if isinstance(raw.get("media"), dict) else {})
    rewards = raw.get("rewards") if isinstance(raw.get("rewards"), dict) else {}

    return {
        "id": eid,
        "subtype": str(raw.get("subtype") or "").strip(),
        "name": str(raw.get("name") or eid).strip(),
        "description": str(raw.get("description") or "").strip(),
        "active": raw.get("active", True) is not False,
        "schedule": _normalize_schedule(raw.get("schedule")),
        "matchmaking": _normalize_matchmaking(raw.get("matchmaking")),
        "match": _normalize_match(raw.get("match")),
        "matches": _normalize_matches(raw.get("matches")),
        "eligibility": _normalize_eligibility(raw.get("eligibility")),
        "arcori": arcori,
        "arena": _normalize_arena(raw.get("arena")),
        "media": media_norm,
        "rewards": rewards,
        "achievement_hooks": {"roster_design_ids": design_ids},
        # Back-compat for event_design_ids() / achievements
        "design_ids": design_ids,
    }


def load_special_events_document() -> tuple[dict[str, Any], str]:
    global _CACHE_DOC, _CACHE_MTIME, _CACHE_REVISION, _BY_ID
    path = _default_data_path()
    try:
        mtime = path.stat().st_mtime
    except OSError:
        return {"schema_version": 2, "events": []}, ""

    if _CACHE_DOC is not None and _CACHE_MTIME == mtime:
        return _CACHE_DOC, _CACHE_REVISION

    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        if LOGGING_SWITCH:
            customlog(f"special_events: load failed path={path} err={exc}")
        return {"schema_version": 2, "events": []}, ""

    if not isinstance(raw, dict):
        return {"schema_version": 2, "events": []}, ""

    try:
        schema_version = int(raw.get("schema_version") or raw.get("schemaVersion") or 2)
    except (TypeError, ValueError):
        schema_version = 2

    events: list[dict[str, Any]] = []
    by_id: dict[str, dict[str, Any]] = {}
    raw_list = raw.get("events")
    if isinstance(raw_list, list):
        for item in raw_list:
            if not isinstance(item, dict):
                continue
            norm = _normalize_event(item)
            if norm is None or norm["id"] in by_id:
                continue
            events.append(norm)
            by_id[norm["id"]] = norm

    doc = {"schema_version": schema_version, "events": events}
    revision = f"{mtime:.6f}:{len(events)}"
    _CACHE_DOC = doc
    _CACHE_MTIME = mtime
    _CACHE_REVISION = revision
    _BY_ID = by_id
    if LOGGING_SWITCH:
        customlog(f"special_events: loaded n={len(events)} rev={revision}")
    return doc, revision


def list_events() -> list[dict[str, Any]]:
    doc, _ = load_special_events_document()
    return list(doc.get("events") or [])


def event_by_id(event_id: str) -> dict[str, Any] | None:
    load_special_events_document()
    return _BY_ID.get((event_id or "").strip())


def event_design_ids(event_id: str) -> list[str]:
    ev = event_by_id(event_id)
    if ev is None:
        return []
    return list(ev.get("design_ids") or [])


def catalog_revision() -> str:
    _, rev = load_special_events_document()
    return rev


def client_event_row(ev: dict[str, Any]) -> dict[str, Any]:
    """CamelCase row for Flutter catalog (rules + media)."""
    mm = ev.get("matchmaking") or {}
    match = ev.get("match") or {}
    matches = ev.get("matches") or {}
    elig = ev.get("eligibility") or {}
    arcori = ev.get("arcori") or {}
    arena = ev.get("arena") or {}
    schedule = ev.get("schedule") or {}
    slammer = elig.get("required_slammer") or {}
    return {
        "id": ev.get("id"),
        "subtype": ev.get("subtype") or "",
        "name": ev.get("name"),
        "description": ev.get("description") or "",
        "active": bool(ev.get("active", True)),
        "schedule": {
            "startsAt": schedule.get("starts_at"),
            "endsAt": schedule.get("ends_at"),
        },
        "matchmaking": {
            "players": int(mm.get("players") or 3),
            "aiFill": bool(mm.get("ai_fill", True)),
            "fillWindowSec": int(mm.get("fill_window_sec") or 5),
            "queueMode": mm.get("queue_mode") or QUEUE_MODE_OPEN,
        },
        "match": {
            "rounds": int(match.get("rounds") or 2),
            "feeFragments": match.get("fee_fragments"),
        },
        "matches": {
            "required": int(matches.get("required") or 1),
            "credit": matches.get("credit") or MATCH_CREDIT_ANY_FINISH,
            "creditParams": matches.get("credit_params") or {},
        },
        "eligibility": {
            "minMasteryValue": float(elig.get("min_mastery_value") or 0),
            "maxMasteryValue": elig.get("max_mastery_value"),
            "requiredTitles": list(elig.get("required_titles") or []),
            "requiredSlammer": {
                "mode": slammer.get("mode") or SLAMMER_MODE_ANY,
                "designIds": list(slammer.get("design_ids") or []),
                "types": list(slammer.get("types") or []),
            },
        },
        "arcori": {
            "perPlayer": int(arcori.get("per_player") or 1),
            "source": arcori.get("source") or ARCORI_SOURCE_CIRCULATION,
            "seriesIds": list(arcori.get("series_ids") or []),
            "generationNumbers": list(arcori.get("generation_numbers") or []),
            "regionCodes": list(arcori.get("region_codes") or []),
            "designIds": list(arcori.get("design_ids") or []),
        },
        "arena": {
            "mode": arena.get("mode") or ARENA_MODE_SEATED_REGIONS,
            "regionCode": arena.get("region_code"),
            "arenaId": arena.get("arena_id"),
        },
        "media": media_for_client(ev.get("media") if isinstance(ev.get("media"), dict) else {}),
        "designIds": list(ev.get("design_ids") or []),
    }
