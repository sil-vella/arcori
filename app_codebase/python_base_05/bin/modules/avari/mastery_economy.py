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
