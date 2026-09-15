"""pay_match_fee / refund_match_fee wallet gates + feeIntentId ledger."""

from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from sqlalchemy.exc import IntegrityError

from core.errors.app_error import AppError
from modules.avari.avari_errors import INSUFFICIENT_GOLD, INVALID_MATCH_FEE
from modules.avari.avari_service import pay_match_fee, refund_match_fee

UID = "a0000000-0000-4000-8000-000000000099"
INTENT = "fee-intent-0001"


def _session_patches(fn):
    patches = [
        patch("modules.avari.avari_service.session_scope"),
        patch("modules.avari.avari_service.get_user_profile"),
        patch("modules.avari.avari_repository.ensure_avari_profile"),
        patch("modules.avari.avari_repository.get_match_fee", return_value=None),
        patch("modules.avari.avari_repository.insert_match_fee"),
    ]
    for p in reversed(patches):
        fn = p(fn)
    return fn


def _session_ctx(scope: MagicMock) -> MagicMock:
    session = MagicMock()
    ctx = MagicMock()
    ctx.__enter__.return_value = session
    ctx.__exit__.return_value = False
    scope.return_value = ctx
    return session


class PayMatchFeeTests(unittest.TestCase):
    def test_rejects_missing_fee_intent(self) -> None:
        with self.assertRaises(AppError) as ctx_err:
            pay_match_fee(UID, {"matchType": "quickStart"})
        self.assertEqual(ctx_err.exception.code, INVALID_MATCH_FEE.code)

    @_session_patches
    def test_pays_when_affordable(
        self,
        insert_fee: MagicMock,
        get_fee: MagicMock,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
    ) -> None:
        get_profile.return_value = {"username": "player"}
        _session_ctx(scope)
        get_fee.return_value = None
        avari = SimpleNamespace(gold_arcori=20, gold_fragments=0)
        ensure.return_value = avari

        out = pay_match_fee(
            UID, {"matchType": "quickStart", "feeIntentId": INTENT}
        )
        self.assertTrue(out["paid"])
        self.assertEqual(out["feeFragments"], 2)
        self.assertEqual(out["goldFragmentsDelta"], -2)
        self.assertEqual(out["feeIntentId"], INTENT)
        self.assertEqual(avari.gold_arcori, 19)
        self.assertEqual(avari.gold_fragments, 2)
        insert_fee.assert_called_once()
        self.assertEqual(insert_fee.call_args.kwargs.get("intent_id"), INTENT)
        self.assertEqual(insert_fee.call_args.kwargs.get("kind"), "pay")

    @_session_patches
    def test_pay_replay_same_intent_no_second_debit(
        self,
        insert_fee: MagicMock,
        get_fee: MagicMock,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
    ) -> None:
        _session_ctx(scope)
        cached = {
            "paid": True,
            "matchType": "quickStart",
            "feeIntentId": INTENT,
            "feeFragments": 2,
            "goldFragmentsDelta": -2,
            "goldFragments": 2,
            "goldArcori": 19,
        }
        get_fee.return_value = SimpleNamespace(response_json=cached)

        out = pay_match_fee(
            UID, {"matchType": "quickStart", "feeIntentId": INTENT}
        )
        self.assertTrue(out["paid"])
        self.assertEqual(out["goldFragments"], 2)
        self.assertEqual(out.get("reason"), "already_applied")
        ensure.assert_not_called()
        insert_fee.assert_not_called()

    @_session_patches
    def test_rejects_insufficient(
        self,
        _insert_fee: MagicMock,
        get_fee: MagicMock,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
    ) -> None:
        get_profile.return_value = {"username": "player"}
        _session_ctx(scope)
        get_fee.return_value = None
        avari = SimpleNamespace(gold_arcori=0, gold_fragments=1)
        ensure.return_value = avari

        with self.assertRaises(AppError) as ctx_err:
            pay_match_fee(UID, {"matchType": "invite", "feeIntentId": INTENT})
        self.assertEqual(ctx_err.exception.code, INSUFFICIENT_GOLD.code)
        self.assertEqual(avari.gold_arcori, 0)
        self.assertEqual(avari.gold_fragments, 1)

    def test_rejects_practice(self) -> None:
        with self.assertRaises(AppError) as ctx_err:
            pay_match_fee(
                UID, {"matchType": "practice", "feeIntentId": INTENT}
            )
        self.assertEqual(ctx_err.exception.code, INVALID_MATCH_FEE.code)

    @_session_patches
    def test_refund_restores_fragments(
        self,
        insert_fee: MagicMock,
        get_fee: MagicMock,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
    ) -> None:
        get_profile.return_value = {"username": "player"}
        _session_ctx(scope)
        get_fee.return_value = None
        avari = SimpleNamespace(gold_arcori=19, gold_fragments=2)
        ensure.return_value = avari

        out = refund_match_fee(
            UID,
            {
                "matchType": "quickStart",
                "feeFragments": 2,
                "feeIntentId": INTENT,
            },
        )
        self.assertTrue(out["refunded"])
        self.assertEqual(out["feeFragments"], 2)
        self.assertEqual(avari.gold_arcori, 20)
        self.assertEqual(avari.gold_fragments, 0)
        insert_fee.assert_called_once()
        self.assertEqual(insert_fee.call_args.kwargs.get("kind"), "refund")

    @_session_patches
    def test_refund_replay_no_double_credit(
        self,
        insert_fee: MagicMock,
        get_fee: MagicMock,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
    ) -> None:
        _session_ctx(scope)
        cached = {
            "refunded": True,
            "feeIntentId": INTENT,
            "feeFragments": 2,
            "goldFragments": 0,
            "goldArcori": 20,
        }
        get_fee.return_value = SimpleNamespace(response_json=cached)

        out = refund_match_fee(
            UID,
            {
                "matchType": "quickStart",
                "feeFragments": 2,
                "feeIntentId": INTENT,
            },
        )
        self.assertTrue(out["refunded"])
        self.assertEqual(out["goldArcori"], 20)
        ensure.assert_not_called()
        insert_fee.assert_not_called()

    def test_refund_rejects_missing_intent(self) -> None:
        with self.assertRaises(AppError) as ctx_err:
            refund_match_fee(UID, {"matchType": "quickStart", "feeFragments": 2})
        self.assertEqual(ctx_err.exception.code, INVALID_MATCH_FEE.code)

    @_session_patches
    def test_pay_integrity_error_returns_cached(
        self,
        insert_fee: MagicMock,
        get_fee: MagicMock,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
    ) -> None:
        get_profile.return_value = {"username": "player"}
        session = MagicMock()
        ctx = MagicMock()
        ctx.__enter__.return_value = session
        ctx.__exit__.return_value = False
        scope.side_effect = [ctx, ctx]
        avari = SimpleNamespace(gold_arcori=20, gold_fragments=0)
        ensure.return_value = avari
        cached = {
            "paid": True,
            "feeIntentId": INTENT,
            "feeFragments": 2,
            "goldFragments": 2,
            "goldArcori": 19,
        }
        get_fee.side_effect = [
            None,
            SimpleNamespace(response_json=cached),
        ]
        insert_fee.side_effect = IntegrityError("stmt", {}, Exception("unique"))

        out = pay_match_fee(
            UID, {"matchType": "quickStart", "feeIntentId": INTENT}
        )
        self.assertTrue(out["paid"])
        self.assertEqual(out["goldFragments"], 2)
        self.assertEqual(out.get("reason"), "already_applied")


if __name__ == "__main__":
    unittest.main()
