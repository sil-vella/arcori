"""Daily Cache claim_goal grants +2 Gold Fragments."""

from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from core.errors.app_error import AppError
from modules.daily_goals.daily_goals_errors import (
    ALREADY_CLAIMED,
    GATE_NOT_MET,
    NOT_CLAIMABLE,
)
from modules.daily_goals.daily_goals_service import claim_goal
from modules.daily_goals.daily_goals_types import TASK_TYPE_CLAIM_GATE


def _goal(
    *,
    goal_id: str = "daily_mystery_box",
    task_type: str = TASK_TYPE_CLAIM_GATE,
    requires: list[str] | None = None,
    amount: int = 2,
    kind: str = "gold_fragments",
) -> dict:
    return {
        "id": goal_id,
        "name": "Daily Cache",
        "task_type": task_type,
        "featured": False,
        "params": {"requires_goal_ids": requires or ["play_one_match", "land_three_flips"]},
        "continue": {"enabled": True, "currency": "gold_arcori", "cost": 2},
        "reward": {"kind": kind, "amount": amount},
        "value": {"kind": "streak", "on_complete_delta": 1, "on_miss": "reset_to_zero"},
        "post_complete_action": {"type": "none"},
        "media": {},
        "section": "tasks",
        "cadence": "daily",
        "description": "",
    }


def _row(**kwargs):
    base = dict(
        value=0,
        day_key="2026-09-19",
        progress_today=0,
        completed_today=False,
        miss_pending=False,
        last_completed_day_key=None,
    )
    base.update(kwargs)
    return SimpleNamespace(**base)


class ClaimGoalTests(unittest.TestCase):
    @patch("modules.daily_goals.daily_goals_service.notify_daily_completions")
    @patch("modules.daily_goals.daily_goals_service.build_progress_payload")
    @patch("modules.daily_goals.daily_goals_service._sync_no_miss_streak", return_value=1)
    @patch("modules.daily_goals.daily_goals_service._mark_complete")
    @patch("modules.daily_goals.daily_goals_service.ensure_all_rollover")
    @patch("modules.daily_goals.daily_goals_service.utc_day_key", return_value="2026-09-19")
    @patch("modules.daily_goals.daily_goals_service.goal_by_id")
    @patch("modules.daily_goals.daily_goals_service.repo")
    def test_claim_grants_fragments_and_sets_claimed_at(
        self,
        repo: MagicMock,
        goal_by_id: MagicMock,
        _day: MagicMock,
        _rollover: MagicMock,
        mark: MagicMock,
        _streak: MagicMock,
        build: MagicMock,
        notify: MagicMock,
    ) -> None:
        goal = _goal(amount=2)
        goal_by_id.return_value = goal
        claim_row = _row()
        req_done = _row(completed_today=True, day_key="2026-09-19")

        def get_progress(_session, _uid, gid):
            if gid in ("play_one_match", "land_three_flips"):
                return req_done
            return None

        repo.upsert_progress_row.return_value = claim_row
        repo.get_progress_row.side_effect = get_progress
        build.return_value = {"goals": [], "dayKey": "2026-09-19"}

        avari = SimpleNamespace(
            gold_arcori=20,
            gold_fragments=0,
            daily_cache_claimed_at=None,
        )
        session = MagicMock()

        out = claim_goal(
            session, user_id="u1", avari=avari, goal_id="daily_mystery_box"
        )

        self.assertEqual(avari.gold_fragments, 2)
        self.assertEqual(avari.gold_arcori, 20)
        self.assertIsNotNone(avari.daily_cache_claimed_at)
        self.assertEqual(out["reward"]["kind"], "gold_fragments")
        self.assertEqual(out["reward"]["amount"], 2)
        self.assertEqual(out["reward"]["status"], "granted")
        self.assertEqual(out["reward"]["goldFragments"], 2)
        mark.assert_called_once()
        notify.assert_called_once()

    @patch("modules.daily_goals.daily_goals_service.notify_daily_completions")
    @patch("modules.daily_goals.daily_goals_service.build_progress_payload")
    @patch("modules.daily_goals.daily_goals_service._sync_no_miss_streak", return_value=0)
    @patch("modules.daily_goals.daily_goals_service._mark_complete")
    @patch("modules.daily_goals.daily_goals_service.ensure_all_rollover")
    @patch("modules.daily_goals.daily_goals_service.utc_day_key", return_value="2026-09-19")
    @patch("modules.daily_goals.daily_goals_service.goal_by_id")
    @patch("modules.daily_goals.daily_goals_service.repo")
    def test_claim_amount_from_json(
        self,
        repo: MagicMock,
        goal_by_id: MagicMock,
        _day: MagicMock,
        _rollover: MagicMock,
        _mark: MagicMock,
        _streak: MagicMock,
        build: MagicMock,
        _notify: MagicMock,
    ) -> None:
        goal_by_id.return_value = _goal(amount=5)
        claim_row = _row()
        req_done = _row(completed_today=True, day_key="2026-09-19")
        repo.upsert_progress_row.return_value = claim_row
        repo.get_progress_row.return_value = req_done
        build.return_value = {"goals": []}
        avari = SimpleNamespace(
            gold_arcori=1, gold_fragments=0, daily_cache_claimed_at=None
        )

        out = claim_goal(
            MagicMock(), user_id="u1", avari=avari, goal_id="daily_mystery_box"
        )
        self.assertEqual(out["reward"]["amount"], 5)
        self.assertEqual(avari.gold_fragments, 1)
        self.assertEqual(avari.gold_arcori, 2)  # 5 frags → 1 arcori + 1 frag

    @patch("modules.daily_goals.daily_goals_service.ensure_all_rollover")
    @patch("modules.daily_goals.daily_goals_service.utc_day_key", return_value="2026-09-19")
    @patch("modules.daily_goals.daily_goals_service.goal_by_id")
    @patch("modules.daily_goals.daily_goals_service.repo")
    def test_reject_double_claim(
        self,
        repo: MagicMock,
        goal_by_id: MagicMock,
        _day: MagicMock,
        _rollover: MagicMock,
    ) -> None:
        goal_by_id.return_value = _goal()
        repo.upsert_progress_row.return_value = _row(completed_today=True)
        avari = SimpleNamespace(gold_arcori=0, gold_fragments=0)
        with self.assertRaises(AppError) as ctx:
            claim_goal(
                MagicMock(), user_id="u1", avari=avari, goal_id="daily_mystery_box"
            )
        self.assertEqual(ctx.exception.code, ALREADY_CLAIMED.code)

    @patch("modules.daily_goals.daily_goals_service.ensure_all_rollover")
    @patch("modules.daily_goals.daily_goals_service.utc_day_key", return_value="2026-09-19")
    @patch("modules.daily_goals.daily_goals_service.goal_by_id")
    @patch("modules.daily_goals.daily_goals_service.repo")
    def test_reject_gate_not_met(
        self,
        repo: MagicMock,
        goal_by_id: MagicMock,
        _day: MagicMock,
        _rollover: MagicMock,
    ) -> None:
        goal_by_id.return_value = _goal()
        repo.upsert_progress_row.return_value = _row()
        repo.get_progress_row.return_value = _row(completed_today=False)
        avari = SimpleNamespace(gold_arcori=0, gold_fragments=0)
        with self.assertRaises(AppError) as ctx:
            claim_goal(
                MagicMock(), user_id="u1", avari=avari, goal_id="daily_mystery_box"
            )
        self.assertEqual(ctx.exception.code, GATE_NOT_MET.code)

    @patch("modules.daily_goals.daily_goals_service.goal_by_id")
    def test_reject_not_claimable(self, goal_by_id: MagicMock) -> None:
        goal_by_id.return_value = _goal(task_type="matches_completed")
        avari = SimpleNamespace(gold_arcori=0, gold_fragments=0)
        with self.assertRaises(AppError) as ctx:
            claim_goal(
                MagicMock(), user_id="u1", avari=avari, goal_id="play_one_match"
            )
        self.assertEqual(ctx.exception.code, NOT_CLAIMABLE.code)


class NormalizeRewardTests(unittest.TestCase):
    def test_mystery_box_defaults_amount(self) -> None:
        from modules.daily_goals.daily_goals_loader import _normalize_reward

        out = _normalize_reward({"kind": "mystery_box"})
        self.assertEqual(out["kind"], "mystery_box")
        self.assertEqual(out["amount"], 2)

    def test_gold_fragments_keeps_amount(self) -> None:
        from modules.daily_goals.daily_goals_loader import _normalize_reward

        out = _normalize_reward({"kind": "gold_fragments", "amount": 3})
        self.assertEqual(out["amount"], 3)


if __name__ == "__main__":
    unittest.main()
