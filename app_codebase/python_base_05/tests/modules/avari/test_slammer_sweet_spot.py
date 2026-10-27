"""Per-player sweet spot is rolled once and then kept."""

from __future__ import annotations

import random
import unittest
from unittest.mock import MagicMock, patch

from modules.avari.slammer_sweet_spot import (
    bind_sweet_spot,
    roll_sweet_spot,
    stored_sweet_spot,
)


_TITAN = {
    "gameplayAttributes": {
        "hitTarget": "edge",
        "powerBracket": {"min": 0.8, "max": 1.0},
    }
}


class RollSweetSpotTests(unittest.TestCase):
    def test_shape_and_bias_seed(self) -> None:
        spot = roll_sweet_spot(_TITAN, rng=random.Random(1))
        self.assertIn(spot["hitTarget"], {"center", "mid", "edge"})
        band = spot["powerBracket"]
        self.assertLess(band["min"], band["max"])
        self.assertGreaterEqual(band["min"], 0.05)
        self.assertLessEqual(band["max"], 0.98)
        self.assertAlmostEqual(band["max"] - band["min"], 0.20, places=2)

    def test_same_seed_same_spot(self) -> None:
        a = roll_sweet_spot(_TITAN, rng=random.Random(7))
        b = roll_sweet_spot(_TITAN, rng=random.Random(7))
        self.assertEqual(a, b)

    def test_different_seeds_can_differ(self) -> None:
        spots = {
            (
                roll_sweet_spot(_TITAN, rng=random.Random(i))["hitTarget"],
                roll_sweet_spot(_TITAN, rng=random.Random(i))["powerBracket"]["min"],
            )
            for i in range(12)
        }
        self.assertGreater(len(spots), 1)

    def test_missing_catalog_still_valid(self) -> None:
        spot = roll_sweet_spot({}, rng=random.Random(3))
        self.assertIn(spot["hitTarget"], {"center", "mid", "edge"})
        self.assertAlmostEqual(
            spot["powerBracket"]["max"] - spot["powerBracket"]["min"],
            0.20,
            places=2,
        )


class BindSweetSpotTests(unittest.TestCase):
    def test_rolls_once_then_keeps(self) -> None:
        row = MagicMock()
        row.sweet_spot = None
        row.design_id = "SLM-SLM-TTN-SER001-GEN001-0002"
        row.user_id = "u1"
        session = MagicMock()
        with patch(
            "modules.avari.slammer_sweet_spot._load_design",
            return_value=_TITAN,
        ):
            first = bind_sweet_spot(session, row, rng=random.Random(4))
            row.sweet_spot = first
            second = bind_sweet_spot(session, row, rng=random.Random(99))
        self.assertEqual(first, second)
        self.assertEqual(session.flush.call_count, 1)
        self.assertEqual(stored_sweet_spot(first), first)

    def test_invalid_stored_rerolls(self) -> None:
        row = MagicMock()
        row.sweet_spot = {"hitTarget": "nope"}
        row.design_id = "SLM-SLM-TTN-SER001-GEN001-0002"
        row.user_id = "u1"
        session = MagicMock()
        spot = bind_sweet_spot(
            session, row, design=_TITAN, rng=random.Random(2)
        )
        self.assertIn(spot["hitTarget"], {"center", "mid", "edge"})
        session.flush.assert_called_once()


if __name__ == "__main__":
    unittest.main()
