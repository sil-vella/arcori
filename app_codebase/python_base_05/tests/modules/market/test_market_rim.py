"""Market shop slammer purchase / recharge + charge spend."""

from __future__ import annotations

import json
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from core.errors.app_error import AppError
from modules.avari.avari_errors import SLAMMER_NO_CHARGES
from modules.market.market_errors import (
    ALREADY_OWNED,
    INSUFFICIENT_GOLD,
    NOT_FOR_SALE,
    NOT_OWNED,
)
from modules.market.market_skus import (
    is_shop_slammer,
    parse_slammer_economy,
)
from modules.market import market_service


RIM_ID = "SLM-SLM-RIM-SER001-GEN001-0011"
STARTER_ID = "SLM-SLM-STR-SER001-GEN001-0001"
_SLAMMERS_JSON = (
    Path(__file__).resolve().parents[3]
    / "bin"
    / "modules"
    / "catalog"
    / "data"
    / "series"
    / "genesis"
    / "slammers.json"
)


def _rim_design() -> dict:
    return {
        "internalId": RIM_ID,
        "design": "Rim Slammer",
        "designCode": "RIM",
        "themeCode": "SLM",
        "type": "Slammer",
        "origin": "Shop",
        "gameplayAttributes": {
            "hitTarget": "edge",
            "powerBracket": {"min": 0.4, "max": 0.6},
        },
        "economy": {
            "permanent": False,
            "maxCharges": 25,
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
        self.assertEqual(eco["maxCharges"], 25)
        self.assertEqual(eco["chargeCostPerUse"], 1)
        self.assertTrue(is_shop_slammer(_rim_design(), design_id=RIM_ID))

    def test_authored_genesis_shop_contract(self) -> None:
        doc = json.loads(_SLAMMERS_JSON.read_text(encoding="utf-8"))
        designs = doc["designs"]
        self.assertEqual(len(designs), 10)
        shop = []
        for design in designs:
            code = design["designCode"]
            eco = parse_slammer_economy(design)
            if code == "STR":
                self.assertEqual(design["origin"], "Starter")
                self.assertTrue(eco["permanent"])
                self.assertFalse(is_shop_slammer(design))
                continue
            shop.append(code)
            self.assertEqual(design["origin"], "Shop")
            self.assertFalse(eco["permanent"])
            self.assertEqual(eco["shopPriceGoldArcori"], 4)
            self.assertEqual(eco["maxCharges"], 25)
            self.assertEqual(eco["chargeCostPerUse"], 1)
            self.assertEqual(eco["rechargePriceGoldArcori"], 4)
            self.assertEqual(eco["rechargeCharges"], 100)
            self.assertTrue(is_shop_slammer(design))
        self.assertEqual(len(shop), 9)
        self.assertFalse(
            is_shop_slammer(
                {
                    "designCode": "GLT",
                    "themeCode": "SLM",
                    "type": "Slammer",
                    "origin": "Event",
                    "economy": {"permanent": False},
                }
            )
        )

    def test_legacy_caps_ignored_for_ga_price(self) -> None:
        eco = parse_slammer_economy(
            {
                "economy": {
                    "permanent": False,
                    "shopPriceGoldCaps": 280,
                    "rechargeCostGoldCaps": 25,
                    "maxCharges": 25,
                }
            }
        )
        # Caps are not Gold Arcori — fall back to Market defaults.
        self.assertEqual(eco["shopPriceGoldArcori"], 4)
        self.assertEqual(eco["rechargePriceGoldArcori"], 4)


class MarketServiceTests(unittest.TestCase):
    def test_purchase_grants_25_charges(self) -> None:
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
        self.assertEqual(out["chargesRemaining"], 25)
        self.assertEqual(out["goldArcoriSpent"], 4)
        self.assertEqual(avari.gold_arcori, 6)
        ensure.assert_called_once()
        kwargs = ensure.call_args.kwargs
        self.assertEqual(kwargs["charges_remaining"], 25)
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

    def test_purchase_starter_not_for_sale(self) -> None:
        session = MagicMock()
        starter = {
            "internalId": STARTER_ID,
            "designCode": "STR",
            "themeCode": "SLM",
            "type": "Slammer",
            "origin": "Starter",
            "economy": {"permanent": True, "chargeCostPerUse": 0},
        }
        with patch.object(market_service, "_design_or_raise", return_value=starter):
            with self.assertRaises(AppError) as ctx:
                market_service.purchase_slammer(
                    session, user_id="u1", design_id=STARTER_ID
                )
        self.assertEqual(ctx.exception.code, NOT_FOR_SALE.code)

    def test_list_skips_starter(self) -> None:
        session = MagicMock()
        avari = MagicMock(gold_arcori=10, gold_fragments=0)

        def _row(iid: str, design: dict):
            row = MagicMock()
            row.internal_id = iid
            row.design_json = design
            return row

        starter = {
            "designCode": "STR",
            "themeCode": "SLM",
            "type": "Slammer",
            "origin": "Starter",
            "economy": {"permanent": True},
        }
        rim = _rim_design()
        with (
            patch.object(market_service, "_ensure_avari", return_value=avari),
            patch.object(
                market_service.catalog_repo,
                "list_by_theme_code",
                return_value=[
                    _row(STARTER_ID, starter),
                    _row(RIM_ID, rim),
                ],
            ),
            patch.object(market_service, "_design_or_raise", return_value=rim),
            patch.object(market_service.avari_repo, "list_slammers", return_value=[]),
        ):
            out = market_service.list_market_slammers(session, user_id="u1")
        self.assertEqual([item["designId"] for item in out["slammers"]], [RIM_ID])

    def test_list_orders_by_catalog_serial(self) -> None:
        session = MagicMock()
        avari = MagicMock(gold_arcori=10, gold_fragments=0)
        titan_id = "SLM-SLM-TTN-SER001-GEN001-0002"
        cyclone_id = "SLM-SLM-CYC-SER001-GEN001-0004"

        def _row(iid: str):
            row = MagicMock()
            row.internal_id = iid
            row.design_json = {
                "internalId": iid,
                "designCode": iid.split("-")[2],
                "themeCode": "SLM",
                "type": "Slammer",
                "origin": "Shop",
                "design": iid,
                "seriesKey": "Genesis",
                "economy": {
                    "permanent": False,
                    "maxCharges": 25,
                    "chargeCostPerUse": 1,
                    "shopPriceGoldArcori": 4,
                    "rechargePriceGoldArcori": 4,
                    "rechargeCharges": 100,
                },
            }
            return row

        designs = {
            titan_id: _row(titan_id).design_json,
            cyclone_id: _row(cyclone_id).design_json,
        }

        def _design(did: str):
            return designs[did]

        with (
            patch.object(market_service, "_ensure_avari", return_value=avari),
            patch.object(
                market_service.catalog_repo,
                "list_by_theme_code",
                return_value=[_row(cyclone_id), _row(titan_id)],
            ),
            patch.object(market_service, "_design_or_raise", side_effect=_design),
            patch.object(market_service.avari_repo, "list_slammers", return_value=[]),
        ):
            out = market_service.list_market_slammers(session, user_id="u1")
        self.assertEqual(
            [item["designId"] for item in out["slammers"]],
            [titan_id, cyclone_id],
        )
        self.assertEqual(out["slammers"][0]["series"], "Genesis")
        self.assertEqual(out["slammers"][0]["seriesOrder"], 1)

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
            patch.object(avari_service.repo, "get_slammer", return_value=row),
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
        self.assertEqual(out["chargesSpent"], 1)
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
            patch.object(avari_service.repo, "get_slammer", return_value=row),
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
            patch.object(avari_service.repo, "get_slammer", return_value=row),
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
