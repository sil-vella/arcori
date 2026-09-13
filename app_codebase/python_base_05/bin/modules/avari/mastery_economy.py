"""Per-player mastery match deltas (circulating designs — not ownership)."""

from __future__ import annotations

from typing import Any

# Creator's own Kin never drops below this; claim starts here.
KIN_CREATOR_MASTERY_FLOOR = 100

# Starter pack access rows begin here (pool excludes mastery < 1).
STARTER_INITIAL_MASTERY = 10


def own_played_delta(seat_flips: int) -> int:
    """Mastery Δ on the Arcori you brought this match."""
    n = max(0, int(seat_flips))
    if n <= 0:
        return -1
    if n == 1:
        return 0
    return 2


def other_design_delta(flips_on_design: int) -> int:
    """Mastery Δ on a non-own design you flipped this match."""
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


def compute_mastery_deltas(
    *,
    played_design_id: str | None,
    seat_flips: int,
    flips_by_design: dict[str, int] | None,
) -> list[dict[str, Any]]:
    """
    Build non-zero mastery change rows for finalize.

    Each row: {designId, delta, flips, kind: "own"|"other"}
    Own uses seat_flips; other uses flips_by_design (excluding played).
    """
    out: list[dict[str, Any]] = []
    played = (played_design_id or "").strip()
    if played:
        delta = own_played_delta(seat_flips)
        if delta != 0:
            out.append(
                {
                    "designId": played,
                    "delta": delta,
                    "flips": max(0, int(seat_flips)),
                    "kind": "own",
                }
            )

    raw = flips_by_design or {}
    for design_id, flips in raw.items():
        did = str(design_id or "").strip()
        if not did or (played and did == played):
            continue
        try:
            n = max(0, int(flips))
        except (TypeError, ValueError):
            continue
        delta = other_design_delta(n)
        if delta == 0:
            continue
        out.append(
            {
                "designId": did,
                "delta": delta,
                "flips": n,
                "kind": "other",
            }
        )
    return out
