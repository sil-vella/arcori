"""Fragment catalog and Play receipt interpretation."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

_BIN = Path(__file__).resolve().parents[3] / "bin"
if str(_BIN) not in sys.path:
    sys.path.insert(0, str(_BIN))

from core.errors.app_error import AppError  # noqa: E402
from modules.avari.gold_economy import apply_fragment_delta  # noqa: E402
from modules.store.fragment_catalog import (  # noqa: E402
    catalog_packs,
    fragments_for_product,
)
from modules.store.play_billing import interpret_product_purchase  # noqa: E402


# Dutch recommended_ui_packages: coins and USD labels, one pack each.
_DUTCH_PACKS = {
    "fragments_100": (100, "$0.99"),
    "fragments_300": (300, "$2.49"),
    "fragments_500": (500, "$3.99"),
    "fragments_700": (700, "$4.99"),
    "fragments_1500": (1500, "$9.99"),
    "fragments_3500": (3500, "$19.99"),
}


class FragmentCatalogTests(unittest.TestCase):
    def test_packs_match_dutch_prices_and_amounts(self) -> None:
        packs = {row["productId"]: row for row in catalog_packs()}
        self.assertEqual(set(packs), set(_DUTCH_PACKS))
        for product_id, (fragments, price) in _DUTCH_PACKS.items():
            self.assertEqual(packs[product_id]["fragments"], fragments)
            self.assertEqual(packs[product_id]["priceLabel"], price)
            self.assertEqual(fragments_for_product(product_id), fragments)

    def test_popular_pack_is_700(self) -> None:
        popular = [row for row in catalog_packs() if row["isPopular"]]
        self.assertEqual([row["productId"] for row in popular], ["fragments_700"])

    def test_unknown_product(self) -> None:
        with self.assertRaises(AppError) as caught:
            fragments_for_product("coins_100")
        self.assertEqual(caught.exception.code, "store/unknown_product")

    def test_grant_folds_into_gold_arcori(self) -> None:
        after_a, after_f, _, _ = apply_fragment_delta(0, 0, fragments_for_product("fragments_100"))
        self.assertEqual((after_a, after_f), (25, 0))


class PlayReceiptTests(unittest.TestCase):
    def test_purchased_and_not_consumed(self) -> None:
        receipt = interpret_product_purchase(
            {"purchaseState": 0, "consumptionState": 0, "orderId": "GPA.1"}
        )
        self.assertEqual(receipt.order_id, "GPA.1")
        self.assertEqual(receipt.consumption_state, 0)

    def test_rejects_unpaid(self) -> None:
        with self.assertRaises(AppError) as caught:
            interpret_product_purchase({"purchaseState": 1, "consumptionState": 0})
        self.assertEqual(caught.exception.code, "store/invalid_receipt")


if __name__ == "__main__":
    unittest.main()
