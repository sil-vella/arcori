"""finalize_match economy + mastery writers."""

from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from sqlalchemy.exc import IntegrityError

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
    patch("modules.avari.avari_repository.list_mastery_rows", return_value=[]),
    patch(
        "modules.avari.avari_service.apply_match_unlocks",
        return_value=[],
    ),
    patch(
        "modules.daily_goals.daily_goals_service.apply_match_event",
        return_value={"dayKey": "2026-09-15", "changedGoalIds": [], "goalsCompleted": []},
    ),
    patch("modules.avari.avari_repository.get_match_finalize", return_value=None),
    patch("modules.avari.avari_repository.insert_match_finalize"),
    patch("modules.avari.avari_service.session_scope"),
    patch("modules.avari.avari_service.get_user_profile"),
    patch("modules.avari.avari_repository.ensure_avari_profile"),
]


def _apply_finalize_patches(fn):
    for p in reversed(_FINALIZE_PATCHES):
        fn = p(fn)
    return fn


def _session_ctx(scope: MagicMock, session: MagicMock | None = None) -> MagicMock:
    session = session or MagicMock()
    ctx = MagicMock()
    ctx.__enter__.return_value = session
    ctx.__exit__.return_value = False
    scope.return_value = ctx
    return session


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
    def test_online_flips_only_no_fee_at_finalize(
        self,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
        insert_ledger: MagicMock,
        get_ledger: MagicMock,
        _daily: MagicMock,
        _unlocks: MagicMock,
        _mastery_rows: MagicMock,
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
        _session_ctx(scope)
        get_ledger.return_value = None

        avari = SimpleNamespace(
            gold_arcori=20,
            gold_fragments=0,
            matches_played=0,
            wins=0,
            flips=0,
            win_streak_current=0,
            win_streak_best=0,
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
        self.assertEqual(out["feeFragments"], 0)
        self.assertEqual(out["flipsRewarded"], 2)
        self.assertEqual(out["goldFragmentsDelta"], 2)
        self.assertEqual(out["goldArcori"], 20)
        self.assertEqual(out["goldFragments"], 2)
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
        insert_ledger.assert_called_once()
        self.assertEqual(insert_ledger.call_args.kwargs.get("match_id"), "m2")

    @_apply_finalize_patches
    def test_online_zero_flips_no_fee_at_finalize(
        self,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
        insert_ledger: MagicMock,
        get_ledger: MagicMock,
        _daily: MagicMock,
        _unlocks: MagicMock,
        _mastery_rows: MagicMock,
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
        _session_ctx(scope)
        get_ledger.return_value = None
        avari = SimpleNamespace(
            gold_arcori=19,
            gold_fragments=2,
            matches_played=0,
            wins=0,
            flips=0,
            win_streak_current=0,
            win_streak_best=0,
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
        self.assertEqual(out["goldFragmentsDelta"], 0)
        self.assertEqual(out["feeFragments"], 0)
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
        insert_ledger.assert_called_once()

    @_apply_finalize_patches
    def test_second_same_match_id_already_applied(
        self,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
        insert_ledger: MagicMock,
        get_ledger: MagicMock,
        daily: MagicMock,
        unlocks: MagicMock,
        _mastery_rows: MagicMock,
        _access: MagicMock,
        _ensure_m: MagicMock,
        apply_m: MagicMock,
        _gen: MagicMock,
        _kin: MagicMock,
        _grant: MagicMock,
        _revoke: MagicMock,
        _sync: MagicMock,
    ) -> None:
        get_profile.return_value = {"username": "player"}
        _session_ctx(scope)
        cached = {
            "applied": True,
            "reason": "economy",
            "matchId": "m-idem",
            "goldFragmentsDelta": 2,
            "goldArcoriDelta": 0,
            "goldFragments": 5,
            "goldArcori": 20,
            "feeFragments": 0,
            "flipsRewarded": 2,
            "masteryChanges": [{"designId": "x", "delta": 2}],
            "achievementsUnlocked": [],
            "daily": None,
            "eventProgress": None,
            "mint": None,
        }
        get_ledger.return_value = SimpleNamespace(response_json=cached)

        out = finalize_match(
            UID,
            {
                "matchId": "m-idem",
                "matchType": "quickStart",
                "practice": False,
                "playedDesignId": "ANM-TIG-SER001-0001",
                "flips": 2,
            },
        )
        self.assertFalse(out["applied"])
        self.assertEqual(out["reason"], "already_applied")
        self.assertEqual(out["goldFragments"], 5)
        self.assertEqual(out["goldArcori"], 20)
        self.assertEqual(out["masteryChanges"], cached["masteryChanges"])
        ensure.assert_not_called()
        apply_m.assert_not_called()
        insert_ledger.assert_not_called()
        unlocks.assert_not_called()
        daily.assert_not_called()

    @_apply_finalize_patches
    @patch(
        "modules.daily_goals.daily_goals_notifications.notify_daily_completions",
    )
    @patch(
        "modules.achievements.achievements_notifications.notify_achievement_unlocks",
    )
    def test_first_apply_then_replay_no_double_writers(
        self,
        notify_ach: MagicMock,
        notify_daily: MagicMock,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
        insert_ledger: MagicMock,
        get_ledger: MagicMock,
        daily: MagicMock,
        unlocks: MagicMock,
        _mastery_rows: MagicMock,
        _access: MagicMock,
        _ensure_m: MagicMock,
        apply_m: MagicMock,
        _gen: MagicMock,
        _kin: MagicMock,
        _grant: MagicMock,
        _revoke: MagicMock,
        _sync: MagicMock,
    ) -> None:
        get_profile.return_value = {"username": "player"}
        _session_ctx(scope)
        avari = SimpleNamespace(
            gold_arcori=20,
            gold_fragments=0,
            matches_played=0,
            wins=0,
            flips=0,
            win_streak_current=0,
            win_streak_best=0,
        )
        ensure.return_value = avari
        apply_m.return_value = (SimpleNamespace(points=2), 0, 2)
        unlocks.return_value = [{"achievementId": "first_win"}]
        daily.return_value = {
            "dayKey": "2026-09-15",
            "changedGoalIds": ["g1"],
            "goalsCompleted": [{"goalId": "g1"}],
        }

        stored: dict = {}

        def get_side_effect(_session, _uid, mid):
            if mid in stored:
                return SimpleNamespace(response_json=dict(stored[mid]))
            return None

        def insert_side_effect(_session, *, user_id, match_id, response):
            stored[match_id] = dict(response)
            return SimpleNamespace(response_json=dict(response))

        get_ledger.side_effect = get_side_effect
        insert_ledger.side_effect = insert_side_effect

        body = {
            "matchId": "m-once",
            "matchType": "quickStart",
            "practice": False,
            "playedDesignId": "ANM-TIG-SER001-0001",
            "flips": 2,
            "result": {"winnerUserIds": [UID]},
        }
        first = finalize_match(UID, body)
        self.assertTrue(first["applied"])
        self.assertEqual(first["reason"], "economy")
        self.assertEqual(avari.matches_played, 1)
        self.assertEqual(avari.gold_fragments, 2)
        self.assertEqual(apply_m.call_count, 1)
        notify_ach.assert_called_once()
        notify_daily.assert_called_once()

        gold_after_first = avari.gold_fragments
        matches_after_first = avari.matches_played
        mastery_calls = apply_m.call_count

        second = finalize_match(UID, body)
        self.assertFalse(second["applied"])
        self.assertEqual(second["reason"], "already_applied")
        self.assertEqual(second["goldFragments"], first["goldFragments"])
        self.assertEqual(avari.gold_fragments, gold_after_first)
        self.assertEqual(avari.matches_played, matches_after_first)
        self.assertEqual(apply_m.call_count, mastery_calls)
        self.assertEqual(insert_ledger.call_count, 1)
        self.assertEqual(notify_ach.call_count, 1)
        self.assertEqual(notify_daily.call_count, 1)

    @_apply_finalize_patches
    def test_integrity_error_returns_cached(
        self,
        ensure: MagicMock,
        get_profile: MagicMock,
        scope: MagicMock,
        insert_ledger: MagicMock,
        get_ledger: MagicMock,
        _daily: MagicMock,
        _unlocks: MagicMock,
        _mastery_rows: MagicMock,
        _access: MagicMock,
        _ensure_m: MagicMock,
        apply_m: MagicMock,
        _gen: MagicMock,
        _kin: MagicMock,
        _grant: MagicMock,
        _revoke: MagicMock,
        _sync: MagicMock,
    ) -> None:
        get_profile.return_value = {"username": "player"}
        session = MagicMock()
        ctx = MagicMock()
        ctx.__enter__.return_value = session
        ctx.__exit__.return_value = False
        # First scope: apply path; second scope: race re-select.
        scope.side_effect = [ctx, ctx]

        avari = SimpleNamespace(
            gold_arcori=20,
            gold_fragments=0,
            matches_played=0,
            wins=0,
            flips=0,
            win_streak_current=0,
            win_streak_best=0,
        )
        ensure.return_value = avari
        apply_m.return_value = (SimpleNamespace(points=1), 0, 1)

        cached = {
            "applied": True,
            "reason": "economy",
            "matchId": "m-race",
            "goldFragments": 3,
            "goldArcori": 20,
            "goldFragmentsDelta": 1,
            "masteryChanges": [],
        }
        get_ledger.side_effect = [
            None,
            SimpleNamespace(response_json=cached),
        ]
        insert_ledger.side_effect = IntegrityError("stmt", {}, Exception("unique"))

        # IntegrityError on insert flush is raised inside with; session_scope
        # re-raises after rollback. Simulate commit failure via insert.
        out = finalize_match(
            UID,
            {
                "matchId": "m-race",
                "matchType": "quickStart",
                "practice": False,
                "playedDesignId": "ANM-TIG-SER001-0001",
                "flips": 1,
            },
        )
        self.assertFalse(out["applied"])
        self.assertEqual(out["reason"], "already_applied")
        self.assertEqual(out["goldFragments"], 3)

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
