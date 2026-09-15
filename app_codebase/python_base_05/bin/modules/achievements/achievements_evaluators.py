"""Achievement type evaluators — registry keyed by achievement_type."""

from __future__ import annotations

from typing import Any, Callable

from modules.achievements.achievements_types import (
    ACHIEVEMENT_TYPE_EVENT_ARCORI_CLEARED,
    ACHIEVEMENT_TYPE_EVENT_FLIPS,
    ACHIEVEMENT_TYPE_MASTERY_POINTS,
    ACHIEVEMENT_TYPE_MATCH_FLAG,
    ACHIEVEMENT_TYPE_TOTAL_FLIPS,
    ACHIEVEMENT_TYPE_TOTAL_MATCHES,
    ACHIEVEMENT_TYPE_TOTAL_WINS,
    ACHIEVEMENT_TYPE_WIN_STREAK,
)
from modules.special_events.special_events_loader import event_design_ids

# Context keys expected by evaluators (built in service after finalize writers).
# wins, matches_played, flips, win_streak_current, is_winner, match_flags: set[str],
# mastery_after: dict[design_id, points]
# event_id: str | None
# event_progress: dict[event_id, {flips, flippedDesignIds}]


EvaluatorFn = Callable[[dict[str, Any], dict[str, Any]], bool]


def _min_param(params: dict[str, Any]) -> int | None:
    try:
        return max(1, int(params.get("min")))
    except (TypeError, ValueError):
        return None


def _eval_total_wins(entry_params: dict[str, Any], ctx: dict[str, Any]) -> bool:
    vmin = _min_param(entry_params)
    if vmin is None:
        return False
    try:
        return int(ctx.get("wins") or 0) >= vmin
    except (TypeError, ValueError):
        return False


def _eval_total_matches(entry_params: dict[str, Any], ctx: dict[str, Any]) -> bool:
    vmin = _min_param(entry_params)
    if vmin is None:
        return False
    try:
        return int(ctx.get("matches_played") or 0) >= vmin
    except (TypeError, ValueError):
        return False


def _eval_total_flips(entry_params: dict[str, Any], ctx: dict[str, Any]) -> bool:
    vmin = _min_param(entry_params)
    if vmin is None:
        return False
    try:
        return int(ctx.get("flips") or 0) >= vmin
    except (TypeError, ValueError):
        return False


def _eval_win_streak(entry_params: dict[str, Any], ctx: dict[str, Any]) -> bool:
    vmin = _min_param(entry_params)
    if vmin is None:
        return False
    try:
        return int(ctx.get("win_streak_current") or 0) >= vmin
    except (TypeError, ValueError):
        return False


def _eval_match_flag(entry_params: dict[str, Any], ctx: dict[str, Any]) -> bool:
    flag = str(entry_params.get("flag") or "").strip().lower()
    if not flag:
        return False
    flags = ctx.get("match_flags") or set()
    if not isinstance(flags, set):
        flags = {str(f).strip().lower() for f in flags if str(f).strip()}
    else:
        flags = {str(f).strip().lower() for f in flags if str(f).strip()}
    if flag not in flags:
        return False
    requires_win = entry_params.get("requires_win", True)
    if requires_win and not bool(ctx.get("is_winner")):
        return False
    return True


def _eval_mastery_points(entry_params: dict[str, Any], ctx: dict[str, Any]) -> bool:
    vmin = _min_param(entry_params)
    if vmin is None:
        return False
    mastery_after = ctx.get("mastery_after") or {}
    if not isinstance(mastery_after, dict):
        return False
    design_id = str(entry_params.get("design_id") or "").strip()
    if design_id:
        try:
            return int(mastery_after.get(design_id) or 0) >= vmin
        except (TypeError, ValueError):
            return False
    for value in mastery_after.values():
        try:
            if int(value) >= vmin:
                return True
        except (TypeError, ValueError):
            continue
    return False


def _event_progress_for(
    entry_params: dict[str, Any], ctx: dict[str, Any]
) -> dict[str, Any]:
    eid = str(entry_params.get("event_id") or entry_params.get("eventId") or "").strip()
    if not eid:
        eid = str(ctx.get("event_id") or "").strip()
    progress_map = ctx.get("event_progress") or {}
    if not isinstance(progress_map, dict) or not eid:
        return {}
    raw = progress_map.get(eid)
    return raw if isinstance(raw, dict) else {}


def _eval_event_flips(entry_params: dict[str, Any], ctx: dict[str, Any]) -> bool:
    vmin = _min_param(entry_params)
    if vmin is None:
        return False
    prog = _event_progress_for(entry_params, ctx)
    try:
        return int(prog.get("flips") or 0) >= vmin
    except (TypeError, ValueError):
        return False


def _eval_event_arcori_cleared(
    entry_params: dict[str, Any], ctx: dict[str, Any]
) -> bool:
    eid = str(entry_params.get("event_id") or entry_params.get("eventId") or "").strip()
    roster_raw = entry_params.get("design_ids") or entry_params.get("designIds")
    roster: list[str] = []
    if isinstance(roster_raw, list) and roster_raw:
        roster = [str(x).strip() for x in roster_raw if str(x).strip()]
    elif eid:
        roster = event_design_ids(eid)
    if not roster:
        return False
    prog = _event_progress_for(entry_params, ctx)
    flipped_raw = prog.get("flippedDesignIds") or prog.get("flipped_design_ids") or []
    if not isinstance(flipped_raw, list):
        return False
    flipped = {str(x).strip() for x in flipped_raw if str(x).strip()}
    return all(did in flipped for did in roster)


_EVALUATORS: dict[str, EvaluatorFn] = {
    ACHIEVEMENT_TYPE_TOTAL_WINS: _eval_total_wins,
    ACHIEVEMENT_TYPE_TOTAL_MATCHES: _eval_total_matches,
    ACHIEVEMENT_TYPE_TOTAL_FLIPS: _eval_total_flips,
    ACHIEVEMENT_TYPE_WIN_STREAK: _eval_win_streak,
    ACHIEVEMENT_TYPE_MATCH_FLAG: _eval_match_flag,
    ACHIEVEMENT_TYPE_MASTERY_POINTS: _eval_mastery_points,
    ACHIEVEMENT_TYPE_EVENT_FLIPS: _eval_event_flips,
    ACHIEVEMENT_TYPE_EVENT_ARCORI_CLEARED: _eval_event_arcori_cleared,
}


def register_evaluator(achievement_type: str, fn: EvaluatorFn) -> None:
    key = (achievement_type or "").strip().lower()
    if key:
        _EVALUATORS[key] = fn


def evaluate_entry(entry: dict[str, Any], ctx: dict[str, Any]) -> bool:
    atype = str(entry.get("achievement_type") or "").strip().lower()
    fn = _EVALUATORS.get(atype)
    if fn is None:
        return False
    params = entry.get("params")
    if not isinstance(params, dict):
        params = {}
    return bool(fn(params, ctx))


def compute_new_unlock_ids(
    catalog: list[dict[str, Any]],
    already_unlocked: set[str],
    ctx: dict[str, Any],
) -> list[str]:
    """Return newly earned achievement ids in catalog order."""
    out: list[str] = []
    for entry in catalog:
        eid = str(entry.get("id") or "").strip()
        if not eid or eid in already_unlocked:
            continue
        if evaluate_entry(entry, ctx):
            out.append(eid)
    return out
