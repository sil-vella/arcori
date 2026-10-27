"""Per-player slammer sweet spot.

Rolled once when a slammer enters that player's collection and stored on
``player_slammers.sweet_spot``. Catalog ``hitTarget`` / ``powerBracket`` are
the archetype the roll is biased from. The saved spot is what online resolve
uses. Clients never receive it.
"""

from __future__ import annotations

import random
from typing import Any

from core.errors.app_error import AppError
from core.utils.dev_logger import customlog

LOGGING_SWITCH = True

_TARGETS = ("center", "mid", "edge")
_DEFAULT_LO = 0.40
_DEFAULT_HI = 0.60
_MIN_WIDTH = 0.12
_MAX_WIDTH = 0.40
_SHIFT = 0.15
_LO_FLOOR = 0.05
_HI_CEILING = 0.98


def _archetype(design: dict[str, Any] | None) -> tuple[str, float, float]:
    attrs = design.get("gameplayAttributes") if isinstance(design, dict) else None
    raw = attrs if isinstance(attrs, dict) else {}
    target = str(raw.get("hitTarget") or "center").strip().lower()
    if target not in _TARGETS:
        target = "center"
    bracket = raw.get("powerBracket")
    lo, hi = _DEFAULT_LO, _DEFAULT_HI
    if isinstance(bracket, dict):
        try:
            lo = float(bracket.get("min"))
            hi = float(bracket.get("max"))
        except (TypeError, ValueError):
            lo, hi = _DEFAULT_LO, _DEFAULT_HI
    if hi < lo:
        lo, hi = hi, lo
    width = hi - lo
    if width < _MIN_WIDTH or width > _MAX_WIDTH:
        width = _DEFAULT_HI - _DEFAULT_LO
        mid = (lo + hi) / 2.0
        lo = mid - width / 2.0
        hi = lo + width
    return target, lo, hi


def roll_sweet_spot(
    design: dict[str, Any] | None = None,
    *,
    rng: random.Random | None = None,
) -> dict[str, Any]:
    """One sweet spot for one grant. Independent each call."""
    pick = rng if rng is not None else random.Random()
    target, lo, hi = _archetype(design)
    others = [name for name in _TARGETS if name != target]
    roll = pick.random()
    if roll < 0.50:
        chosen = target
    elif roll < 0.75:
        chosen = others[0]
    else:
        chosen = others[1]

    width = hi - lo
    shifted = lo + pick.uniform(-_SHIFT, _SHIFT)
    ceiling = _HI_CEILING - width
    if shifted < _LO_FLOOR:
        shifted = _LO_FLOOR
    if shifted > ceiling:
        shifted = ceiling
    new_hi = shifted + width
    return {
        "hitTarget": chosen,
        "powerBracket": {
            "min": round(shifted, 2),
            "max": round(new_hi, 2),
        },
    }


def stored_sweet_spot(raw: Any) -> dict[str, Any] | None:
    """Return a spot only when both fields are present and valid."""
    if not isinstance(raw, dict):
        return None
    target = str(raw.get("hitTarget") or "").strip().lower()
    if target not in _TARGETS:
        return None
    bracket = raw.get("powerBracket")
    if not isinstance(bracket, dict):
        return None
    try:
        lo = float(bracket.get("min"))
        hi = float(bracket.get("max"))
    except (TypeError, ValueError):
        return None
    if hi < lo:
        return None
    return {
        "hitTarget": target,
        "powerBracket": {"min": round(lo, 2), "max": round(hi, 2)},
    }


def bind_sweet_spot(
    session: Any,
    row: Any,
    *,
    design: dict[str, Any] | None = None,
    rng: random.Random | None = None,
) -> dict[str, Any]:
    """Return the row's spot, rolling and saving one when it is missing."""
    existing = stored_sweet_spot(getattr(row, "sweet_spot", None))
    if existing is not None:
        return existing

    if design is None:
        design_id = str(getattr(row, "design_id", "") or "").strip()
        design = _load_design(design_id)

    spot = roll_sweet_spot(design, rng=rng)
    row.sweet_spot = spot
    session.flush()
    if LOGGING_SWITCH:
        band = spot["powerBracket"]
        customlog(
            "avari: sweet_spot bind "
            f"user={getattr(row, 'user_id', '-') or '-'} "
            f"design={getattr(row, 'design_id', '-') or '-'} "
            f"hit={spot['hitTarget']} "
            f"band={band['min']:.2f}-{band['max']:.2f}"
        )
    return spot


def _load_design(design_id: str) -> dict[str, Any]:
    if not design_id:
        return {}
    try:
        from modules.catalog.catalog_service import get_design

        found = get_design(design_id)
    except AppError:
        return {}
    return found if isinstance(found, dict) else {}
