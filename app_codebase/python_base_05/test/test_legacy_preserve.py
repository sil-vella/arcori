"""Legacy preserve — race claim, expire, fulfill idempotency (unittest)."""

from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch
from uuid import uuid4

from core.errors.app_error import AppError
from modules.legacy import legacy_service as svc
from modules.legacy.legacy_errors import INTENT_NOT_FOUND, NOT_ELIGIBLE


def _life(
    *,
    phase: str = "racing",
    design_id: str = "design.a",
    gen: int = 1,
    first_offer_user_id=None,
    leader_user_id=None,
    leader_since=None,
    first_offer_expires_at=None,
    preservation_requirement: int = 100,
    closure_milestone: int = 500,
):
    row = MagicMock()
    row.design_id = design_id
    row.generation_number = gen
    row.phase = phase
    row.legacy_state = "circulating"
    row.preservation_requirement = preservation_requirement
    row.closure_milestone = closure_milestone
    row.first_offer_user_id = first_offer_user_id
    row.first_offer_expires_at = first_offer_expires_at
    row.leader_user_id = leader_user_id
    row.leader_since = leader_since
    row.leader_window_ends_at = None
    row.preserved_user_id = None
    return row


class TestLegacyPreserve(unittest.TestCase):
    def test_on_mastery_first_offer_claim_idempotent_second_caller(self):
        uid_a = str(uuid4())
        uid_b = str(uuid4())
        life = _life(phase="racing", preservation_requirement=100)

        session = MagicMock()
        with patch.object(svc.repo, "ensure_lifecycle", return_value=life), patch.object(
            svc,
            "get_design",
            return_value={"preservationRequirement": 100, "closureMilestone": 500},
        ), patch.object(
            svc, "mint_reach_or_series_default", return_value=100
        ), patch.object(
            svc, "_closure_milestone_for_design", return_value=500
        ), patch.object(
            svc.repo, "days_from_now", return_value=datetime.now(timezone.utc)
        ), patch.object(
            svc.repo, "minutes_from_now", return_value=datetime.now(timezone.utc)
        ), patch.object(
            svc.repo, "utcnow", return_value=datetime.now(timezone.utc)
        ), patch.object(svc.repo, "get_mastery_points", return_value=120):
            first = svc.on_mastery_progress(
                session,
                user_id=uid_a,
                design_id="design.a",
                generation_number=1,
                points_after=120,
            )
            self.assertIsNotNone(first)
            self.assertIn("legacyOffer", first)
            self.assertEqual(life.phase, "first_offer")
            self.assertEqual(str(life.first_offer_user_id), uid_a)

            second = svc.on_mastery_progress(
                session,
                user_id=uid_b,
                design_id="design.a",
                generation_number=1,
                points_after=130,
            )
            self.assertTrue(second is None or "legacyOffer" not in second)
            self.assertEqual(str(life.first_offer_user_id), uid_a)

    def test_expire_open_first_offers_enters_leader_window(self):
        uid = uuid4()
        life = _life(
            phase="first_offer",
            first_offer_user_id=uid,
            first_offer_expires_at=datetime.now(timezone.utc) - timedelta(seconds=1),
            leader_user_id=uid,
        )
        session = MagicMock()
        with patch(
            "modules.legacy.legacy_service.session_scope"
        ) as scope, patch.object(
            svc.repo, "list_open_first_offers", return_value=[life]
        ), patch.object(
            svc.repo, "days_from_now", return_value=datetime.now(timezone.utc)
        ), patch.object(
            svc.repo, "minutes_from_now", return_value=datetime.now(timezone.utc)
        ), patch.object(svc.repo, "utcnow", return_value=datetime.now(timezone.utc)):
            scope.return_value.__enter__.return_value = session
            out = svc.tick_expire_offers()
        self.assertEqual(out["expiredOffers"], 1)
        self.assertEqual(life.phase, "leader_window")
        self.assertIsNone(life.first_offer_expires_at)

    def test_fulfill_replay_same_order_id_returns_already_applied(self):
        existing = MagicMock()
        existing.response_json = {
            "applied": True,
            "reason": "preserved",
            "designId": "design.a",
            "generationNumber": 1,
        }
        with patch(
            "modules.legacy.legacy_service.session_scope"
        ) as scope, patch.object(svc.repo, "get_fulfill", return_value=existing):
            scope.return_value.__enter__.return_value = MagicMock()
            out = svc.fulfill_from_website(
                {
                    "orderId": "ord-1",
                    "intentId": str(uuid4()),
                    "userId": str(uuid4()),
                    "designId": "design.a",
                    "generationNumber": 1,
                }
            )
        self.assertEqual(out["reason"], "already_applied")
        self.assertFalse(out["applied"])

    def test_preserve_complete_processing_when_ledger_missing(self):
        intent_id = str(uuid4())
        user_id = str(uuid4())
        intent = MagicMock()
        intent.user_id = user_id
        intent.design_id = "design.a"
        intent.generation_number = 1
        with patch(
            "modules.legacy.legacy_service.session_scope"
        ) as scope, patch.object(
            svc.repo, "get_intent", return_value=intent
        ), patch.object(svc.repo, "get_fulfill", return_value=None), patch.object(
            svc.repo, "get_fulfill_by_intent", return_value=None
        ):
            scope.return_value.__enter__.return_value = MagicMock()
            out = svc.preserve_complete(
                user_id, {"intentId": intent_id, "orderId": "ord-missing"}
            )
        self.assertEqual(out["status"], "processing")
        self.assertEqual(out["reason"], "processing")

    def test_preserve_complete_wrong_user_raises(self):
        intent = MagicMock()
        intent.user_id = str(uuid4())
        with patch(
            "modules.legacy.legacy_service.session_scope"
        ) as scope, patch.object(svc.repo, "get_intent", return_value=intent):
            scope.return_value.__enter__.return_value = MagicMock()
            with self.assertRaises(AppError) as ei:
                svc.preserve_complete(
                    str(uuid4()), {"intentId": str(uuid4()), "orderId": "o1"}
                )
        self.assertEqual(ei.exception.code, INTENT_NOT_FOUND.code)

    def test_assert_can_preserve_rejects_closed(self):
        life = _life(phase="preserved")
        with self.assertRaises(AppError) as ei:
            svc._assert_can_preserve(MagicMock(), life, str(uuid4()))
        self.assertEqual(ei.exception.code, NOT_ELIGIBLE.code)

    def test_proximity_gaps_crossed_per_position(self):
        self.assertEqual(
            svc._proximity_gaps_crossed(gap_before=7, gap_after=3),
            [5, 4, 3],
        )
        self.assertEqual(
            svc._proximity_gaps_crossed(gap_before=5, gap_after=4),
            [4],
        )
        self.assertEqual(
            svc._proximity_gaps_crossed(gap_before=4, gap_after=4),
            [],
        )
        self.assertEqual(
            svc._proximity_gaps_crossed(gap_before=3, gap_after=6),
            [],
        )

    def test_on_mastery_leader_window_proximity_emits_each_gap(self):
        leader = uuid4()
        challenger = str(uuid4())
        life = _life(
            phase="leader_window",
            leader_user_id=leader,
            preservation_requirement=100,
            closure_milestone=1000,
        )
        session = MagicMock()
        with patch.object(svc.repo, "ensure_lifecycle", return_value=life), patch.object(
            svc,
            "get_design",
            return_value={"design": "Grey Wolf", "legacy": {"closureMilestone": 1000}},
        ), patch.object(
            svc, "mint_reach_or_series_default", return_value=100
        ), patch.object(
            svc, "_closure_milestone_for_design", return_value=1000
        ), patch.object(
            # Leader at 510; challenger 504→506 → gaps 6→4 → emit 5,4
            svc.repo,
            "get_mastery_points",
            return_value=510,
        ):
            out = svc.on_mastery_progress(
                session,
                user_id=challenger,
                design_id="design.a",
                generation_number=1,
                points_after=506,
                points_before=504,
            )
        self.assertIsNotNone(out)
        events = out["legacyProximity"]
        self.assertEqual([e["gap"] for e in events], [5, 4])
        self.assertEqual(events[0]["arcoriDisplayName"], "Grey Wolf")
        self.assertEqual(events[0]["leaderUserId"], str(leader))
        self.assertEqual(events[0]["challengerUserId"], challenger)

    def test_on_mastery_first_offer_no_proximity(self):
        leader = uuid4()
        challenger = str(uuid4())
        life = _life(
            phase="first_offer",
            leader_user_id=leader,
            first_offer_user_id=leader,
            preservation_requirement=100,
            closure_milestone=1000,
        )
        session = MagicMock()
        with patch.object(svc.repo, "ensure_lifecycle", return_value=life), patch.object(
            svc, "get_design", return_value={"design": "Lion"}
        ), patch.object(
            svc, "mint_reach_or_series_default", return_value=100
        ), patch.object(
            svc, "_closure_milestone_for_design", return_value=1000
        ), patch.object(svc.repo, "get_mastery_points", return_value=510):
            out = svc.on_mastery_progress(
                session,
                user_id=challenger,
                design_id="design.a",
                generation_number=1,
                points_after=506,
                points_before=504,
            )
        self.assertTrue(out is None or "legacyProximity" not in out)

    def test_notify_legacy_leader_proximity_creates_pressure_and_chase(self):
        from modules.legacy import legacy_notifications as notif

        leader = str(uuid4())
        challenger = str(uuid4())
        created_calls: list[dict] = []

        def _fake_create(uid, **kwargs):
            created_calls.append({"userId": uid, **kwargs})

        with patch.object(notif, "create_for_user", side_effect=_fake_create), patch.object(
            notif, "_player_display_name", side_effect=lambda u: f"name-{u[:8]}"
        ), patch.object(notif, "_arcori_display_name", return_value="Grey Wolf"):
            n = notif.notify_legacy_leader_proximity(
                events=[
                    {
                        "designId": "ANM-GWO-SER001-0010",
                        "generationNumber": 1,
                        "gap": 5,
                        "leaderUserId": leader,
                        "challengerUserId": challenger,
                        "leaderPoints": 510,
                        "challengerPoints": 505,
                        "arcoriDisplayName": "Grey Wolf",
                    },
                    {
                        "designId": "ANM-GWO-SER001-0010",
                        "generationNumber": 1,
                        "gap": 4,
                        "leaderUserId": leader,
                        "challengerUserId": challenger,
                        "leaderPoints": 510,
                        "challengerPoints": 506,
                        "arcoriDisplayName": "Grey Wolf",
                    },
                ]
            )
        self.assertEqual(n, 4)  # 2 gaps × (pressure + chase)
        subtypes = [c["subtype"] for c in created_calls]
        self.assertEqual(subtypes.count("pressure_v1"), 2)
        self.assertEqual(subtypes.count("chase_v1"), 2)
        gaps_in_ids = {
            c["msg_id"].rsplit(":", 1)[-1] for c in created_calls
        }
        self.assertEqual(gaps_in_ids, {"5", "4"})


if __name__ == "__main__":
    unittest.main()
