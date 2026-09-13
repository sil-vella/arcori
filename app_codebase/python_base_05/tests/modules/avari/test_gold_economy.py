"""Gold Fragments / Gold Arcori wallet helpers."""

from __future__ import annotations

import unittest

from modules.avari.gold_economy import (
    FRAGMENTS_PER_GOLD_ARCORI,
    SIGNUP_GOLD_ARCORI,
    apply_fragment_delta,
    match_fee_fragments,
    normalize_wallet,
)


class GoldEconomyTests(unittest.TestCase):
    def test_constants(self) -> None:
        self.assertEqual(FRAGMENTS_PER_GOLD_ARCORI, 4)
        self.assertEqual(SIGNUP_GOLD_ARCORI, 20)
        self.assertEqual(match_fee_fragments("quickStart"), 2)
        self.assertEqual(match_fee_fragments("specialEvent"), 2)

    def test_normalize_folds_fragments(self) -> None:
        self.assertEqual(normalize_wallet(0, 4), (1, 0))
        self.assertEqual(normalize_wallet(1, 6), (2, 2))
        self.assertEqual(normalize_wallet(0, 0), (0, 0))

    def test_apply_fee_and_flips_max(self) -> None:
        # 20 Gold Arcori, fee 2, 6 flips → net +4 frags → 21 Gold Arcori + 0 frags
        a, f, da, _ = apply_fragment_delta(20, 0, 6 - 2)
        self.assertEqual((a, f), (21, 0))
        self.assertEqual(da, 1)

    def test_apply_fee_zero_flips(self) -> None:
        a, f, da, _ = apply_fragment_delta(20, 0, 0 - 2)
        self.assertEqual((a, f), (19, 2))
        self.assertEqual(da, -1)

    def test_apply_cannot_go_below_zero(self) -> None:
        a, f, _, _ = apply_fragment_delta(0, 0, -2)
        self.assertEqual((a, f), (0, 0))


if __name__ == "__main__":
    unittest.main()
