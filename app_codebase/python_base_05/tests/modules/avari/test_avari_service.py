"""Avari profile service — persisted vs stub shape."""

from __future__ import annotations

import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from modules.avari.avari_service import get_avari_profile


class AvariServiceTests(unittest.TestCase):
    @patch("modules.avari.avari_service.session_scope")
    @patch("modules.avari.avari_service.get_user_profile")
    def test_persisted_profile_shape(self, get_profile: MagicMock, scope: MagicMock) -> None:
        get_profile.return_value = {
            "user_id": "a0000000-0000-4000-8000-000000000001",
            "username": "admin",
            "email": "admin@reignofplay.com",
            "account_type": "Regular",
            "avatar_url": None,
        }
        session = MagicMock()
        ctx = MagicMock()
        ctx.__enter__.return_value = session
        ctx.__exit__.return_value = False
        scope.return_value = ctx

        avari = SimpleNamespace(
            display_name="Admin",
            primary_title="Avari",
            titles=["Avari"],
            rank_xp=0,
            rank_level=1,
            rank_label=None,
            matches_played=0,
            wins=0,
            flips=0,
            gold_fragments=0,
            gold_caps=5,
            onboarding_completed=True,
            onboarding_kin_chosen=True,
            onboarding_genesis_created=True,
            onboarding_starter_granted=True,
            onboarding_guided_practice_done=True,
            onboarding_intros_done=True,
            daily_login_streak=0,
            daily_last_login_reward_at=None,
            daily_cache_claimed_at=None,
            daily_no_miss_streak=0,
            notifications_push=True,
        )
        kin = SimpleNamespace(
            subtheme="Entelairs",
            style="Chibi",
            finish="Standard",
            effect="None",
            genesis_design_id="KIN-SIL202607092145-GEN001-0001",
            chosen_name="Admin",
            customization={},
        )
        access = [
            SimpleNamespace(design_id="ANM-TIG-GEN001-0001", source="starter"),
        ]
        slammer = SimpleNamespace(
            design_id="SLM-STR-GEN001-0001",
            permanent=True,
            charges_remaining=None,
            source="starter",
        )

        with patch("modules.avari.avari_repository.find_avari_profile", return_value=avari), patch(
            "modules.avari.avari_repository.ensure_avari_profile", return_value=avari
        ), patch(
            "modules.avari.avari_repository.find_player_kin", return_value=kin
        ), patch(
            "modules.avari.avari_repository.list_mastery_top", return_value=[]
        ), patch(
            "modules.avari.avari_repository.count_mastery_designs", return_value=0
        ), patch(
            "modules.avari.avari_repository.list_design_access", return_value=access
        ), patch(
            "modules.avari.avari_repository.list_slammers", return_value=[slammer]
        ), patch(
            "modules.avari.avari_repository.list_trove", return_value=[]
        ):
            payload = get_avari_profile("a0000000-0000-4000-8000-000000000001")

        self.assertEqual(payload["identity"]["displayName"], "Admin")
        self.assertEqual(payload["economy"]["goldCaps"], 5)
        self.assertEqual(payload["kin"]["subtheme"], "Entelairs")
        self.assertEqual(payload["access"][0]["designId"], "ANM-TIG-GEN001-0001")
        self.assertEqual(payload["slammers"][0]["designId"], "SLM-STR-GEN001-0001")
        self.assertTrue(payload["onboarding"]["completed"])
        self.assertEqual(payload["trove"], [])


if __name__ == "__main__":
    unittest.main()
