"""Unit tests for mastery match deltas."""

from __future__ import annotations

import unittest

from modules.avari.mastery_economy import (
    clamp_points,
    compute_mastery_deltas,
    other_design_delta,
    own_played_delta,
)


class MasteryEconomyTests(unittest.TestCase):
    def test_own_curve(self) -> None:
        self.assertEqual(own_played_delta(0), -1)
        self.assertEqual(own_played_delta(1), 0)
        self.assertEqual(own_played_delta(2), 2)
        self.assertEqual(own_played_delta(6), 2)

    def test_other_curve(self) -> None:
        self.assertEqual(other_design_delta(0), 0)
        self.assertEqual(other_design_delta(1), 1)
        self.assertEqual(other_design_delta(2), 2)
        self.assertEqual(other_design_delta(9), 2)

    def test_clamp(self) -> None:
        self.assertEqual(clamp_points(-3), 0)
        self.assertEqual(clamp_points(4), 4)
        self.assertEqual(clamp_points(50, floor=100), 100)
        self.assertEqual(clamp_points(150, floor=100), 150)

    def test_compute_own_and_other(self) -> None:
        rows = compute_mastery_deltas(
            played_design_id="OWN",
            seat_flips=0,
            flips_by_design={"OWN": 0, "FOX": 1, "WOLF": 2},
        )
        by_id = {r["designId"]: r for r in rows}
        self.assertEqual(by_id["OWN"]["delta"], -1)
        self.assertEqual(by_id["OWN"]["kind"], "own")
        self.assertEqual(by_id["FOX"]["delta"], 1)
        self.assertEqual(by_id["FOX"]["kind"], "other")
        self.assertEqual(by_id["WOLF"]["delta"], 2)
        self.assertNotIn("OWN", {r["designId"] for r in rows if r["kind"] == "other"})

    def test_compute_skips_zero_other_and_break_even_own(self) -> None:
        rows = compute_mastery_deltas(
            played_design_id="OWN",
            seat_flips=1,
            flips_by_design={"FOX": 0},
        )
        self.assertEqual(rows, [])


if __name__ == "__main__":
    unittest.main()
