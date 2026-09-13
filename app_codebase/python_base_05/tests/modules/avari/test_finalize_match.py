"""finalize_match economy + mastery writers."""

from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from core.errors.app_error import AppError
from modules.avari.avari_errors import INVALID_MATCH_FINALIZE
from modules.avari.avari_service import finalize_match

UID = "a0000000-0000-4000-8000-000000000099"

_FINALIZE_PATCHES = [
    patch("modules.avari.avari_service.sync_player_access_pool", return_value=None),
    patch("modules.avari.avari_repository.revoke_design_access"),
    patch("modules.avari.avari_repository.ensure_design_access"),
    patch("modules.avari.avari_repository.find_player_kin", return_value=None),
    patch("modules.avari.avari_service.generation_number_for_design_id", return_value=1),
    patch("modules.avari.avari_repository.apply_mastery_delta"),
    patch("modules.avari.avari_repository.ensure_mastery_row"),
    patch("modules.avari.avari_repository.list_design_access", return_value=[]),
    patch("modules.avari.avari_service.session_scope"),
    patch("modules.avari.avari_service.get_user_profile"),
    patch("modules.avari.avari_repository.ensure_avari_profile"),
]


def _apply_finalize_patches(fn):
    for p in reversed(_FINALIZE_PATCHES):
        fn = p(fn)
    return fn


class FinalizeMatchTests(unittest.TestCase):
    def test_practice_skip(self) -> None:
        out = finalize_match(
            UID,
            {
                "matchId": "m1",
                "matchType": "practice",
                "practice": True,
                "designIds": ["ANM-TIG-SER001-0001"],
                "flips": 3,
                "result": {"finalScores": {}},
            },
        )
        self.assertFalse(out["applied"])
        self.assertEqual(out["reason"], "practice")
        self.assertEqual(out["goldFragmentsDelta"], 0)
        self.assertEqual(out["masteryChanges"], [])

    @_apply_finalize_patches
    def test_online_fee_and_flips(
        self,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
        _access: MagicMock,
        _ensure_m: MagicMock,
        apply_m: MagicMock,
        _gen: MagicMock,
        _kin: MagicMock,
        grant: MagicMock,
        _revoke: MagicMock,
        _sync: MagicMock,
    ) -> None:
        get_profile.return_value = {"username": "player"}
        session = MagicMock()
        ctx = MagicMock()
        ctx.__enter__.return_value = session
        ctx.__exit__.return_value = False
        scope.return_value = ctx

        avari = SimpleNamespace(
            gold_arcori=20,
            gold_fragments=0,
            matches_played=0,
            wins=0,
            flips=0,
        )
        ensure.return_value = avari

        def apply_side_effect(*args, **kwargs):
            did = kwargs.get("design_id") or ""
            if did.endswith("0001"):
                return (SimpleNamespace(points=2), 0, 2)
            return (SimpleNamespace(points=1), 0, 1)

        apply_m.side_effect = apply_side_effect

        out = finalize_match(
            UID,
            {
                "matchId": "m2",
                "matchType": "quickStart",
                "practice": False,
                "designIds": ["ANM-TIG-SER001-0001"],
                "playedDesignId": "ANM-TIG-SER001-0001",
                "flips": 2,
                "flipsByDesign": {"ANM-FOX-SER001-0002": 1},
                "result": {
                    "winnerUserIds": [UID],
                },
            },
        )
        self.assertTrue(out["applied"])
        self.assertEqual(out["reason"], "economy")
        self.assertEqual(out["feeFragments"], 2)
        self.assertEqual(out["flipsRewarded"], 2)
        self.assertEqual(out["goldFragmentsDelta"], 0)
        self.assertEqual(out["goldArcori"], 20)
        self.assertEqual(out["goldFragments"], 0)
        self.assertEqual(avari.matches_played, 1)
        self.assertEqual(avari.wins, 1)
        self.assertEqual(avari.flips, 2)
        self.assertEqual(apply_m.call_count, 2)
        kinds = {c["kind"] for c in out["masteryChanges"]}
        self.assertEqual(kinds, {"own", "other"})
        for change in out["masteryChanges"]:
            self.assertIn("mintReach", change)
            self.assertIn("displayName", change)
            self.assertIn("pointsAfter", change)
        grant_ids = [c.kwargs.get("design_id") for c in grant.call_args_list]
        self.assertIn("ANM-FOX-SER001-0002", grant_ids)

    @_apply_finalize_patches
    def test_online_zero_flips_pays_fee_and_own_penalty(
        self,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
        _access: MagicMock,
        _ensure_m: MagicMock,
        apply_m: MagicMock,
        _gen: MagicMock,
        _kin: MagicMock,
        _grant: MagicMock,
        revoke: MagicMock,
        _sync: MagicMock,
    ) -> None:
        get_profile.return_value = {"username": "player"}
        session = MagicMock()
        ctx = MagicMock()
        ctx.__enter__.return_value = session
        ctx.__exit__.return_value = False
        scope.return_value = ctx
        avari = SimpleNamespace(
            gold_arcori=20,
            gold_fragments=0,
            matches_played=0,
            wins=0,
            flips=0,
        )
        ensure.return_value = avari
        apply_m.return_value = (SimpleNamespace(points=0), 1, 0)

        out = finalize_match(
            UID,
            {
                "matchId": "m3",
                "matchType": "invite",
                "practice": False,
                "playedDesignId": "ANM-TIG-SER001-0001",
                "flips": 0,
            },
        )
        self.assertTrue(out["applied"])
        self.assertEqual(out["goldFragmentsDelta"], -2)
        self.assertEqual(out["goldArcori"], 19)
        self.assertEqual(out["goldFragments"], 2)
        self.assertEqual(avari.wins, 0)
        self.assertEqual(len(out["masteryChanges"]), 1)
        self.assertEqual(out["masteryChanges"][0]["kind"], "own")
        self.assertEqual(out["masteryChanges"][0]["delta"], -1)
        revoke.assert_called()
        self.assertEqual(
            revoke.call_args.kwargs.get("design_id"), "ANM-TIG-SER001-0001"
        )

    def test_rejects_missing_match_id(self) -> None:
        with self.assertRaises(AppError) as ctx:
            finalize_match(
                UID,
                {"practice": False},
            )
        self.assertEqual(ctx.exception.code, INVALID_MATCH_FINALIZE.code)

    def test_rejects_bad_design_ids(self) -> None:
        with self.assertRaises(AppError) as ctx:
            finalize_match(
                UID,
                {"matchId": "m3", "designIds": "nope"},
            )
        self.assertEqual(ctx.exception.code, INVALID_MATCH_FINALIZE.code)


if __name__ == "__main__":
    unittest.main()
