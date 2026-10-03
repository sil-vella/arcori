"""Unit tests for mastery match deltas."""

from __future__ import annotations

import unittest

from modules.avari.mastery_economy import (
    clamp_points,
    compute_mastery_deltas,
    compute_mastery_value,
    echo_mastery_seed,
    mastery_value_contribution,
    mastery_value_density,
    mastery_value_factor,
    mastery_value_label,
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

    def test_echo_mastery_seed_ratio_and_cap(self) -> None:
        # 80 × 0.30 → 24; under preserve-1
        self.assertEqual(echo_mastery_seed(80, preservation_requirement=100), 24)
        # Cap below preserve offer line
        self.assertEqual(echo_mastery_seed(500, preservation_requirement=100), 99)
        # Low points still stay in pool
        self.assertEqual(echo_mastery_seed(1, preservation_requirement=100), 1)
        self.assertEqual(echo_mastery_seed(0, preservation_requirement=100), 0)

    def test_compute_own_and_other(self) -> None:
        rows = compute_mastery_deltas(
            played_design_id="OWN",
            flips_by_design={"OWN": 0, "FOX": 1, "WOLF": 2},
            table_design_ids=["OWN", "FOX", "WOLF"],
            owned_design_ids={"OWN"},
        )
        by_id = {r["designId"]: r for r in rows}
        self.assertEqual(by_id["OWN"]["delta"], -1)
        self.assertEqual(by_id["OWN"]["kind"], "own")
        self.assertEqual(by_id["OWN"]["flips"], 0)
        self.assertEqual(by_id["FOX"]["delta"], 1)
        self.assertEqual(by_id["FOX"]["kind"], "other")
        self.assertEqual(by_id["WOLF"]["delta"], 2)
        self.assertNotIn("OWN", {r["designId"] for r in rows if r["kind"] == "other"})

    def test_owned_not_played_no_deduction_on_zero_flips(self) -> None:
        """Opponent brought a design you already master — 0 flips → no row."""
        rows = compute_mastery_deltas(
            played_design_id="OWN",
            flips_by_design={"OWN": 1, "CHE": 1},
            table_design_ids=["OWN", "CHE", "WTI"],
            owned_design_ids={"OWN", "WTI"},
        )
        by_id = {r["designId"]: r for r in rows}
        # Played: 1 flip of OWN → break-even (omitted)
        self.assertNotIn("OWN", by_id)
        # New design flipped once → other +1
        self.assertEqual(by_id["CHE"]["delta"], 1)
        self.assertEqual(by_id["CHE"]["kind"], "other")
        # Already-mastered on table, not played, 0 flips → no deduction
        self.assertNotIn("WTI", by_id)

    def test_played_uses_flips_on_own_design_not_seat_total(self) -> None:
        """Seat total 2 (flipped WTI twice) while never flipping OWN → −1 on OWN."""
        rows = compute_mastery_deltas(
            played_design_id="OWN",
            flips_by_design={"OWN": 0, "WTI": 2},
            table_design_ids=["OWN", "WTI"],
            owned_design_ids={"OWN", "WTI"},
        )
        by_id = {r["designId"]: r for r in rows}
        self.assertEqual(by_id["OWN"]["delta"], -1)
        self.assertEqual(by_id["OWN"]["flips"], 0)
        self.assertEqual(by_id["OWN"]["kind"], "own")
        # Already-mastered opponent pick, 2 flips → +2
        self.assertEqual(by_id["WTI"]["delta"], 2)
        self.assertEqual(by_id["WTI"]["kind"], "own")

    def test_played_two_flips_on_own_gets_plus_two(self) -> None:
        rows = compute_mastery_deltas(
            played_design_id="OWN",
            flips_by_design={"OWN": 2, "FOX": 1},
            table_design_ids=["OWN", "FOX"],
            owned_design_ids={"OWN"},
        )
        by_id = {r["designId"]: r for r in rows}
        self.assertEqual(by_id["OWN"]["delta"], 2)
        self.assertEqual(by_id["OWN"]["flips"], 2)
        self.assertEqual(by_id["FOX"]["delta"], 1)
        self.assertEqual(by_id["FOX"]["kind"], "other")

    def test_opponent_flips_of_my_design_absent_from_my_map(self) -> None:
        """Other players flipping my piece only appear on their finalize."""
        rows = compute_mastery_deltas(
            played_design_id="OWN",
            flips_by_design={},  # I flipped nothing; others may have flipped OWN
            table_design_ids=["OWN", "FOX"],
            owned_design_ids={"OWN"},
        )
        by_id = {r["designId"]: r for r in rows}
        self.assertEqual(by_id["OWN"]["delta"], -1)
        self.assertEqual(by_id["OWN"]["flips"], 0)
        self.assertNotIn("FOX", by_id)

    def test_compute_skips_zero_other_and_break_even_own(self) -> None:
        rows = compute_mastery_deltas(
            played_design_id="OWN",
            flips_by_design={"OWN": 1, "FOX": 0},
            table_design_ids=["OWN", "FOX"],
            owned_design_ids={"OWN"},
        )
        self.assertEqual(rows, [])

    def test_mastery_value_from_selection_weight(self) -> None:
        self.assertAlmostEqual(mastery_value_factor(10.0), 1.0)
        self.assertAlmostEqual(mastery_value_factor(0.1), 100.0)
        self.assertAlmostEqual(mastery_value_factor(0.01), 1000.0)
        self.assertAlmostEqual(mastery_value_contribution(10, 0.1), 1000.0)
        self.assertAlmostEqual(
            compute_mastery_value([(10, 0.1), (10, 10.0)]),
            1010.0,
        )

    def test_mastery_value_label_bands(self) -> None:
        # density = value / N
        self.assertEqual(mastery_value_label(0, 100), "Fair")
        self.assertEqual(mastery_value_label(49, 100), "Fair")  # 0.49
        self.assertEqual(mastery_value_label(50, 100), "Notable")  # 0.50
        self.assertEqual(mastery_value_label(149, 100), "Notable")
        self.assertEqual(mastery_value_label(150, 100), "Sought")
        self.assertEqual(mastery_value_label(399, 100), "Sought")
        self.assertEqual(mastery_value_label(400, 100), "Coveted")
        self.assertEqual(mastery_value_label(999, 100), "Coveted")
        self.assertEqual(mastery_value_label(1000, 100), "Exquisite")
        self.assertEqual(mastery_value_label(2499, 100), "Exquisite")
        self.assertEqual(mastery_value_label(2500, 100), "Priceless")
        self.assertAlmostEqual(mastery_value_density(100, 50), 2.0)
