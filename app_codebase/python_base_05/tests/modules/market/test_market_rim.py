"""Market Rim purchase / recharge + charge spend."""

from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from core.errors.app_error import AppError
from modules.avari.avari_errors import SLAMMER_NO_CHARGES
from modules.market.market_errors import (
    ALREADY_OWNED,
    INSUFFICIENT_GOLD,
    NOT_OWNED,
)
from modules.market.market_skus import (
    MARKET_SLAMMER_IDS,
    parse_slammer_economy,
)
from modules.market import market_service


RIM_ID = MARKET_SLAMMER_IDS[0]


def _rim_design() -> dict:
    return {
        "internalId": RIM_ID,
        "design": "Rim Slammer",
        "gameplayAttributes": {
            "hitTarget": "edge",
            "powerBracket": {"min": 0.4, "max": 0.6},
        },
        "economy": {
            "permanent": False,
            "maxCharges": 20,
            "chargeCostPerUse": 1,
            "shopPriceGoldArcori": 4,
            "rechargePriceGoldArcori": 4,
            "rechargeCharges": 100,
        },
    }


class ParseEconomyTests(unittest.TestCase):
    def test_rim_prices(self) -> None:
        eco = parse_slammer_economy(_rim_design())
        self.assertEqual(eco["shopPriceGoldArcori"], 4)
        self.assertEqual(eco["rechargePriceGoldArcori"], 4)
        self.assertEqual(eco["rechargeCharges"], 100)
        self.assertEqual(eco["maxCharges"], 20)

    def test_legacy_caps_ignored_for_ga_price(self) -> None:
        eco = parse_slammer_economy(
            {
                "economy": {
                    "permanent": False,
                    "shopPriceGoldCaps": 280,
                    "rechargeCostGoldCaps": 25,
                    "maxCharges": 20,
                }
            }
        )
        # Caps are not Gold Arcori — fall back to Market defaults.
        self.assertEqual(eco["shopPriceGoldArcori"], 4)
        self.assertEqual(eco["rechargePriceGoldArcori"], 4)


class MarketServiceTests(unittest.TestCase):
    def test_purchase_grants_20_charges(self) -> None:
        session = MagicMock()
        avari = MagicMock(gold_arcori=10, gold_fragments=0)
        with (
            patch.object(market_service, "_ensure_avari", return_value=avari),
            patch.object(market_service, "_design_or_raise", return_value=_rim_design()),
            patch.object(market_service, "_owned_row", return_value=None),
            patch.object(market_service.avari_repo, "ensure_slammer") as ensure,
        ):
            out = market_service.purchase_slammer(
                session, user_id="u1", design_id=RIM_ID
            )
        self.assertEqual(out["chargesRemaining"], 20)
        self.assertEqual(out["goldArcoriSpent"], 4)
        self.assertEqual(avari.gold_arcori, 6)
        ensure.assert_called_once()
        kwargs = ensure.call_args.kwargs
        self.assertEqual(kwargs["charges_remaining"], 20)
        self.assertFalse(kwargs["permanent"])

    def test_purchase_insufficient_gold(self) -> None:
        session = MagicMock()
        avari = MagicMock(gold_arcori=3, gold_fragments=0)
        with (
            patch.object(market_service, "_ensure_avari", return_value=avari),
            patch.object(market_service, "_design_or_raise", return_value=_rim_design()),
            patch.object(market_service, "_owned_row", return_value=None),
        ):
            with self.assertRaises(AppError) as ctx:
                market_service.purchase_slammer(
                    session, user_id="u1", design_id=RIM_ID
                )
        self.assertEqual(ctx.exception.code, INSUFFICIENT_GOLD.code)

    def test_purchase_already_owned(self) -> None:
        session = MagicMock()
        with (
            patch.object(market_service, "_design_or_raise", return_value=_rim_design()),
            patch.object(market_service, "_owned_row", return_value=MagicMock()),
        ):
            with self.assertRaises(AppError) as ctx:
                market_service.purchase_slammer(
                    session, user_id="u1", design_id=RIM_ID
                )
        self.assertEqual(ctx.exception.code, ALREADY_OWNED.code)

    def test_recharge_adds_100_for_4(self) -> None:
        session = MagicMock()
        avari = MagicMock(gold_arcori=8, gold_fragments=0)
        row = MagicMock(permanent=False, charges_remaining=5)
        with (
            patch.object(market_service, "_ensure_avari", return_value=avari),
            patch.object(market_service, "_design_or_raise", return_value=_rim_design()),
            patch.object(market_service, "_owned_row", return_value=row),
        ):
            out = market_service.recharge_slammer(
                session, user_id="u1", design_id=RIM_ID
            )
        self.assertEqual(out["chargesAdded"], 100)
        self.assertEqual(out["chargesRemaining"], 105)
        self.assertEqual(out["goldArcoriSpent"], 4)
        self.assertEqual(avari.gold_arcori, 4)

    def test_recharge_not_owned(self) -> None:
        session = MagicMock()
        with (
            patch.object(market_service, "_design_or_raise", return_value=_rim_design()),
            patch.object(market_service, "_owned_row", return_value=None),
        ):
            with self.assertRaises(AppError) as ctx:
                market_service.recharge_slammer(
                    session, user_id="u1", design_id=RIM_ID
                )
        self.assertEqual(ctx.exception.code, NOT_OWNED.code)


class SpendChargeTests(unittest.TestCase):
    def test_spend_decrements(self) -> None:
        from modules.avari import avari_service

        row = MagicMock(permanent=False, charges_remaining=3, design_id=RIM_ID)
        session = MagicMock()
        session_cm = MagicMock()
        session_cm.__enter__.return_value = session
        session_cm.__exit__.return_value = False

        with (
            patch.object(avari_service, "session_scope", return_value=session_cm),
            patch.object(avari_service.repo, "list_slammers", return_value=[row]),
            patch.object(avari_service.repo, "get_match_fee", return_value=None),
            patch.object(avari_service.repo, "insert_match_fee"),
            patch.object(avari_service, "get_design", return_value=_rim_design()),
        ):
            out = avari_service.spend_slammer_charge(
                user_id="11111111-1111-1111-1111-111111111111",
                design_id=RIM_ID,
                intent_id="test-intent-1",
            )
        self.assertTrue(out["spent"])
        self.assertEqual(row.charges_remaining, 2)

    def test_spend_at_zero_fails(self) -> None:
        from modules.avari import avari_service

        row = MagicMock(permanent=False, charges_remaining=0, design_id=RIM_ID)
        session = MagicMock()
        session_cm = MagicMock()
        session_cm.__enter__.return_value = session
        session_cm.__exit__.return_value = False

        with (
            patch.object(avari_service, "session_scope", return_value=session_cm),
            patch.object(avari_service.repo, "list_slammers", return_value=[row]),
            patch.object(avari_service.repo, "get_match_fee", return_value=None),
        ):
            with self.assertRaises(AppError) as ctx:
                avari_service.spend_slammer_charge(
                    user_id="11111111-1111-1111-1111-111111111111",
                    design_id=RIM_ID,
                )
        self.assertEqual(ctx.exception.code, SLAMMER_NO_CHARGES.code)

    def test_permanent_noop(self) -> None:
        from modules.avari import avari_service

        row = MagicMock(permanent=True, charges_remaining=None, design_id="SLM-STR")
        session = MagicMock()
        session_cm = MagicMock()
        session_cm.__enter__.return_value = session
        session_cm.__exit__.return_value = False

        with (
            patch.object(avari_service, "session_scope", return_value=session_cm),
            patch.object(avari_service.repo, "list_slammers", return_value=[row]),
            patch.object(avari_service.repo, "get_match_fee", return_value=None),
        ):
            out = avari_service.spend_slammer_charge(
                user_id="11111111-1111-1111-1111-111111111111",
                design_id="SLM-STR",
            )
        self.assertTrue(out["noop"])
        self.assertFalse(out["spent"])


if __name__ == "__main__":
    unittest.main()
