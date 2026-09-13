"""ensure_avari_profile signup Gold Arcori + starter pack."""

from __future__ import annotations

import unittest
import uuid
from unittest.mock import MagicMock, patch

from models.avari_profile import AvariProfile
from modules.avari.avari_repository import ensure_avari_profile
from modules.avari.gold_economy import SIGNUP_GOLD_ARCORI


class EnsureAvariProfileTests(unittest.TestCase):
    @patch("modules.avari.starter_grant.grant_starter_pack", return_value=[])
    def test_new_profile_gets_signup_gold_arcori(self, grant: MagicMock) -> None:
        session = MagicMock()
        scalars = MagicMock()
        scalars.first.return_value = None
        session.scalars.return_value = scalars

        out = ensure_avari_profile(
            session,
            user_id=uuid.UUID("a0000000-0000-4000-8000-000000000099"),
            display_name="Guest",
        )
        self.assertIsInstance(out, AvariProfile)
        self.assertEqual(out.gold_arcori, SIGNUP_GOLD_ARCORI)
        session.add.assert_called_once_with(out)
        grant.assert_called_once()

    @patch("modules.avari.starter_grant.grant_starter_pack", return_value=[])
    def test_existing_without_starter_grants_pack(self, grant: MagicMock) -> None:
        session = MagicMock()
        existing = AvariProfile(
            user_id=uuid.UUID("a0000000-0000-4000-8000-000000000099"),
            display_name="Guest",
            primary_title="Avari",
            titles=["Avari"],
            gold_arcori=20,
            onboarding_starter_granted=False,
        )
        scalars = MagicMock()
        scalars.first.return_value = existing
        session.scalars.return_value = scalars

        out = ensure_avari_profile(
            session,
            user_id=existing.user_id,
            display_name="Guest",
        )
        self.assertIs(out, existing)
        grant.assert_called_once()


if __name__ == "__main__":
    unittest.main()
