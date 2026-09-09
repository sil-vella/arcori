"""finalize_match stub validation."""

from __future__ import annotations

import unittest

from core.errors.app_error import AppError
from modules.avari.avari_errors import INVALID_MATCH_FINALIZE
from modules.avari.avari_service import finalize_match


class FinalizeMatchTests(unittest.TestCase):
    def test_practice_skip(self) -> None:
        out = finalize_match(
            "a0000000-0000-4000-8000-000000000099",
            {
                "matchId": "m1",
                "matchType": "practice",
                "practice": True,
                "designIds": ["ANM-TIG-GEN001-0001"],
                "result": {"finalScores": {}},
            },
        )
        self.assertFalse(out["applied"])
        self.assertEqual(out["reason"], "practice")
        self.assertEqual(out["goldFragmentsDelta"], 0)
        self.assertEqual(out["masteryChanges"], [])

    def test_online_stub(self) -> None:
        out = finalize_match(
            "a0000000-0000-4000-8000-000000000099",
            {
                "matchId": "m2",
                "matchType": "quickStart",
                "practice": False,
                "designIds": ["ANM-TIG-GEN001-0001"],
            },
        )
        self.assertFalse(out["applied"])
        self.assertEqual(out["reason"], "stub")
        self.assertIsNone(out["daily"])
        self.assertIsNone(out["mint"])

    def test_rejects_missing_match_id(self) -> None:
        with self.assertRaises(AppError) as ctx:
            finalize_match(
                "a0000000-0000-4000-8000-000000000099",
                {"practice": False},
            )
        self.assertEqual(ctx.exception.code, INVALID_MATCH_FINALIZE.code)

    def test_rejects_bad_design_ids(self) -> None:
        with self.assertRaises(AppError) as ctx:
            finalize_match(
                "a0000000-0000-4000-8000-000000000099",
                {"matchId": "m3", "designIds": "nope"},
            )
        self.assertEqual(ctx.exception.code, INVALID_MATCH_FINALIZE.code)


if __name__ == "__main__":
    unittest.main()
