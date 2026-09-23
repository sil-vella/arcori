"""Per-player mastery match deltas (circulating designs — not ownership)."""

from __future__ import annotations

from typing import Any, Iterable

# Creator's own Kin never drops below this; claim starts here.
KIN_CREATOR_MASTERY_FLOOR = 100

# Starter pack access rows begin here (pool excludes mastery < 1).
STARTER_INITIAL_MASTERY = 10

# Soft reset on Legacy echo: seed new-gen mastery from closed gen (not a move).
ECHO_MASTERY_SEED_RATIO = 0.30
# Anyone with closed-gen mastery > 0 keeps at least this on the echo (if cap allows).
ECHO_MASTERY_SEED_MIN = 1


def echo_mastery_seed(
    closed_points: int,
    *,
    preservation_requirement: int,
    ratio: float = ECHO_MASTERY_SEED_RATIO,
) -> int:
    """Mastery points to grant on the echo generation (closed row unchanged).

    Soft reset: ``floor(closed × ratio)``, at least [ECHO_MASTERY_SEED_MIN] when
    the player had any closed mastery, capped at ``preservationRequirement − 1``
    so the seed alone never triggers a Preserve offer.
    """
    pts = max(0, int(closed_points))
    if pts <= 0:
        return 0
    preserve = max(1, int(preservation_requirement))
    cap = preserve - 1
    seeded = int(pts * float(ratio))
    if seeded < ECHO_MASTERY_SEED_MIN:
        seeded = ECHO_MASTERY_SEED_MIN
    if seeded > cap:
        seeded = cap
    return max(0, int(seeded))


def own_played_delta(seat_flips: int) -> int:
    """Mastery Δ on a design you already have mastery on (own curve).

    Used for: (1) the Arcori you brought — keyed off seat total flips;
    (2) any other table design you already have mastery on — keyed off
    flips of that design (0 flips → −1).
    """
    n = max(0, int(seat_flips))
    if n <= 0:
        return -1
    if n == 1:
        return 0
    return 2


def other_design_delta(flips_on_design: int) -> int:
    """Mastery Δ on a non-owned design you flipped this match."""
    n = max(0, int(flips_on_design))
    if n <= 0:
        return 0
    if n == 1:
        return 1
    return 2


def clamp_points(points: int, *, floor: int = 0) -> int:
    """Clamp mastery points to [floor, +inf)."""
    return max(int(floor), int(points))


# selectionWeight scale: 0.01 (rarest) … 10.00 (most common).
SELECTION_WEIGHT_MIN = 0.01
SELECTION_WEIGHT_MAX = 10.0
SELECTION_WEIGHT_COMMON_REF = 10.0  # factor 1.0 at most-common


def clamp_selection_weight(raw: Any, *, default: float = 3.0) -> float:
    """Clamp design selectionWeight into the legal range."""
    try:
        if raw is None:
            val = float(default)
        else:
            val = float(raw)
    except (TypeError, ValueError):
        val = float(default)
    if val <= 0:
        val = SELECTION_WEIGHT_MIN
    return max(SELECTION_WEIGHT_MIN, min(SELECTION_WEIGHT_MAX, val))


def mastery_value_factor(selection_weight: Any) -> float:
    """How much one mastery point is worth for this design (rarer → higher)."""
    w = clamp_selection_weight(selection_weight)
    return SELECTION_WEIGHT_COMMON_REF / w


def mastery_value_contribution(points: int, selection_weight: Any) -> float:
    """points × (10.0 / selectionWeight)."""
    return max(0, int(points)) * mastery_value_factor(selection_weight)


def compute_mastery_value(
    rows: list[tuple[int, Any]],
) -> float:
    """Σ masteryPoints × (10.0 / selectionWeight) over (points, weight) rows."""
    total = 0.0
    for points, weight in rows:
        total += mastery_value_contribution(points, weight)
    return total


# Profile display: density = MasteryValue / N_circulating → label.
# N = global circulating playable catalog count (Active, not SLM/KIN/slammer).
# Bands are half-open on the right: Fair [0, 0.5), … Exquisite [10, 25), Priceless [25, ∞).
MASTERY_VALUE_LABEL_FAIR = "Fair"
MASTERY_VALUE_LABEL_NOTABLE = "Notable"
MASTERY_VALUE_LABEL_SOUGHT = "Sought"
MASTERY_VALUE_LABEL_COVETED = "Coveted"
MASTERY_VALUE_LABEL_EXQUISITE = "Exquisite"
MASTERY_VALUE_LABEL_PRICELESS = "Priceless"

# (exclusive upper bound, label) — last band uses +inf.
MASTERY_VALUE_LABEL_BANDS: tuple[tuple[float, str], ...] = (
    (0.5, MASTERY_VALUE_LABEL_FAIR),
    (1.5, MASTERY_VALUE_LABEL_NOTABLE),
    (4.0, MASTERY_VALUE_LABEL_SOUGHT),
    (10.0, MASTERY_VALUE_LABEL_COVETED),
    (25.0, MASTERY_VALUE_LABEL_EXQUISITE),
    (float("inf"), MASTERY_VALUE_LABEL_PRICELESS),
)


def mastery_value_density(mastery_value: float, circulating_count: int) -> float:
    """MasteryValue / max(1, N) — scales with catalog size."""
    n = max(1, int(circulating_count))
    try:
        v = float(mastery_value)
    except (TypeError, ValueError):
        v = 0.0
    if v < 0:
        v = 0.0
    return v / n


def mastery_value_label(mastery_value: float, circulating_count: int) -> str:
    """Map density to Fair … Priceless (profile display SSOT)."""
    density = mastery_value_density(mastery_value, circulating_count)
    for upper, label in MASTERY_VALUE_LABEL_BANDS:
        if density < upper:
            return label
    return MASTERY_VALUE_LABEL_PRICELESS


def _clean_id(value: Any) -> str:
    return str(value or "").strip()


def _flip_count(raw: dict[str, int], design_id: str) -> int:
    try:
        return max(0, int(raw.get(design_id, 0)))
    except (TypeError, ValueError):
        return 0


def compute_mastery_deltas(
    *,
    played_design_id: str | None,
    seat_flips: int,
    flips_by_design: dict[str, int] | None,
    table_design_ids: Iterable[str] | None = None,
    owned_design_ids: Iterable[str] | None = None,
) -> list[dict[str, Any]]:
    """
    Build non-zero mastery change rows for finalize.

    Each row: {designId, delta, flips, kind: "own"|"other"}

    - **Played** design: own curve from ``seat_flips`` (match total you flipped).
    - **Owned** table designs (mastery > 0 already, incl. opponents' picks you
      already progress on): own curve from flips of that design (0 → −1).
    - **Other** (no prior mastery): other curve from flips of that design.
    """
    out: list[dict[str, Any]] = []
    played = _clean_id(played_design_id)
    raw: dict[str, int] = {}
    for key, value in (flips_by_design or {}).items():
        did = _clean_id(key)
        if not did:
            continue
        try:
            raw[did] = max(0, int(value))
        except (TypeError, ValueError):
            continue

    owned = {_clean_id(x) for x in (owned_design_ids or []) if _clean_id(x)}
    table: set[str] = set()
    for x in table_design_ids or []:
        did = _clean_id(x)
        if did:
            table.add(did)
    # Always evaluate played + anything you flipped.
    if played:
        table.add(played)
    table.update(raw.keys())

    for design_id in sorted(table):
        flips_on = _flip_count(raw, design_id)
        if played and design_id == played:
            delta = own_played_delta(seat_flips)
            kind = "own"
            # Display flips-on-this-design (seat total only drives delta).
            flips_field = flips_on
        elif design_id in owned:
            delta = own_played_delta(flips_on)
            kind = "own"
            flips_field = flips_on
        else:
            delta = other_design_delta(flips_on)
            kind = "other"
            flips_field = flips_on
        if delta == 0:
            continue
        out.append(
            {
                "designId": design_id,
                "delta": delta,
                "flips": flips_field,
                "kind": kind,
            }
        )
    return out
